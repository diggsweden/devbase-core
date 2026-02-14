#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Gum-based TUI for DevBase setup
# Beautiful, modern interactive prompts using charmbracelet/gum

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Source common functions shared with whiptail implementation
# shellcheck source=collect-user-preferences-common.sh
source "${DEVBASE_ROOT}/libs/collect-user-preferences-common.sh"

# =============================================================================
# GUM STYLING CONFIGURATION (Everforest-dark theme)
# =============================================================================

# Everforest-dark palette (256-color approximations)
_GUM_ACCENT="108"  # Aqua/cyan - primary accent
_GUM_SUBTLE="245"  # Gray for subtle text
_GUM_SUCCESS="142" # Green for success
_GUM_WARNING="214" # Orange/yellow for warnings
_GUM_ERROR="167"   # Red for errors

# =============================================================================
# CANCELLATION HANDLING
# =============================================================================

# Track if we're in a gum command (to detect Ctrl+C)
_GUM_CANCELLED=false

# Brief: Handle user cancellation (Ctrl+C)
_gum_handle_cancel() {
  _GUM_CANCELLED=true
  # Reset terminal state
  stty echo 2>/dev/null || true
  echo
  gum style --foreground "$_GUM_WARNING" "Setup cancelled by user"
  echo
  exit 130
}

# Brief: Check if gum command was cancelled and exit if so
# Usage: result=$(gum ... ) || _gum_exit_on_cancel
# Note: gum returns exit code 130 on Ctrl+C, or 1 on Escape/cancel
_gum_exit_on_cancel() {
  local exit_code=$?
  # Exit codes: 130 = SIGINT (Ctrl+C), 1 = user cancelled (Escape or No)
  # We treat 130 as cancellation, but 1 might be valid "No" response for confirm
  if [[ $exit_code -eq 130 ]] || [[ "$_GUM_CANCELLED" == "true" ]]; then
    _gum_handle_cancel
  fi
  return $exit_code
}

# Brief: Check exit code and exit on Ctrl+C (for commands where any failure = cancel)
# Usage: gum choose ... || _gum_exit_on_cancel_any
_gum_exit_on_cancel_any() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]] || [[ "$_GUM_CANCELLED" == "true" ]]; then
    _gum_handle_cancel
  fi
}

# Set up trap for Ctrl+C - works at any time during gum TUI
trap '_gum_handle_cancel' INT TERM

# =============================================================================
# GUM PRIMITIVES
# =============================================================================

# Brief: Display a styled header
_gum_header() {
  local title="$1"
  gum style \
    --foreground "$_GUM_ACCENT" \
    --border double \
    --border-foreground "$_GUM_ACCENT" \
    --padding "0 2" \
    --margin "1 0" \
    "$title"
}

# Brief: Display a styled section title
_gum_section() {
  local title="$1"
  echo
  gum style \
    --foreground "$_GUM_ACCENT" \
    --bold \
    "━━━ $title ━━━"
  echo
}

# Brief: Display subtle help text
_gum_help() {
  gum style --foreground "$_GUM_SUBTLE" "$1"
}

# Brief: Display success message
_gum_success() {
  gum style --foreground "$_GUM_SUCCESS" "✓ $1"
}

# Brief: Display warning message
_gum_warning() {
  gum style --foreground "$_GUM_WARNING" "⚠ $1"
}

# Brief: Display error message
_gum_error() {
  gum style --foreground "$_GUM_ERROR" "✗ $1"
}

# Brief: Prompt for text input
# Params: $1 - placeholder, $2 - default value (optional), $3 - header (optional)
# Returns: User input, exits on Ctrl+C or Escape
_gum_input() {
  local placeholder="$1"
  local default="${2:-}"
  local header="${3:-}"

  local args=(--placeholder "$placeholder")
  [[ -n "$default" ]] && args+=(--value "$default")
  [[ -n "$header" ]] && args+=(--header "$header")
  args+=(--width 60)
  args+=(--prompt "> ")
  args+=(--prompt.foreground "$_GUM_ACCENT")
  args+=(--cursor.foreground "$_GUM_ACCENT")
  args+=(--header.foreground "$_GUM_SUBTLE")

  local result
  result=$(gum input "${args[@]}") || _gum_exit_on_cancel_any
  echo "$result"
}

# Brief: Prompt for password input
# Params: $1 - placeholder, $2 - header (optional)
# Returns: Password, exits on Ctrl+C or Escape
_gum_password() {
  local placeholder="$1"
  local header="${2:-}"

  local args=(--placeholder "$placeholder" --password)
  [[ -n "$header" ]] && args+=(--header "$header")
  args+=(--width 60)
  args+=(--prompt "> ")
  args+=(--prompt.foreground "$_GUM_ACCENT")
  args+=(--cursor.foreground "$_GUM_ACCENT")
  args+=(--header.foreground "$_GUM_SUBTLE")

  local result
  result=$(gum input "${args[@]}") || _gum_exit_on_cancel_any
  echo "$result"
}

# Brief: Prompt for yes/no confirmation
# Params: $1 - prompt, $2 - default (affirmative/negative)
# Returns: 0 for Yes, 1 for No, exits on Ctrl+C
_gum_confirm() {
  local prompt="$1"
  local default="${2:-affirmative}"

  local args=("$prompt")
  [[ "$default" == "negative" ]] && args+=(--default=false)
  args+=(--affirmative "Yes" --negative "No")

  local exit_code
  gum confirm "${args[@]}"
  exit_code=$?

  # Exit code 130 = Ctrl+C, exit immediately
  if [[ $exit_code -eq 130 ]]; then
    _gum_handle_cancel
  fi

  return $exit_code
}

# Brief: Choose single item from list
# Params: $@ - items to choose from
# Returns: Selected item, exits on Ctrl+C or Escape
_gum_choose() {
  local result
  result=$(gum choose \
    --no-show-help \
    --cursor "> " \
    --cursor.foreground "$_GUM_ACCENT" \
    --selected.foreground "$_GUM_ACCENT" \
    "$@") || _gum_exit_on_cancel_any
  echo "$result"
}

# Brief: Choose multiple items from list
# Params: $1 - comma-separated pre-selected items (or empty), $@ - items to choose from
# Returns: Selected items (newline-separated), exits on Ctrl+C
_gum_choose_multi() {
  local preselected="$1"
  shift

  local args=(
    --no-limit
    --no-show-help
    --cursor "> "
    --cursor.foreground "$_GUM_ACCENT"
    --selected.foreground "$_GUM_ACCENT"
    --cursor-prefix "  "
    --selected-prefix "✓ "
    --unselected-prefix "  "
  )

  if [[ -n "${GUM_CHOOSE_HEADER:-}" ]]; then
    args+=(--header "$GUM_CHOOSE_HEADER")
  fi

  # Add pre-selected items (comma-separated in single --selected flag)
  if [[ -n "$preselected" ]]; then
    args+=(--selected "$preselected")
  fi

  local result
  result=$(gum choose "${args[@]}" "$@") || _gum_exit_on_cancel_any
  echo "$result"
}

# Brief: Filter items with fuzzy search
# Params: items via stdin, $1 - header (optional)
# Returns: Selected item, exits on Ctrl+C
_gum_filter() {
  local header="${1:-}"
  local args=()

  [[ -n "$header" ]] && args+=(--header "$header")
  args+=(--indicator.foreground "$_GUM_ACCENT")
  args+=(--match.foreground "$_GUM_ACCENT")

  local result
  local exit_code
  result=$(gum filter "${args[@]}")
  exit_code=$?

  # Exit code 130 = Ctrl+C, 1 = cancelled/no selection
  if [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 1 ]]; then
    _gum_handle_cancel
  fi

  echo "$result"
}

# =============================================================================
# COLLECTION FUNCTIONS - GUM UI
# =============================================================================

collect_git_configuration() {
  local name_pattern='^[[:alpha:]]+[[:space:]]+[[:alpha:]]+$'
  local email_pattern='^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  _gum_section "Git Configuration"
  _gum_help "Used for commit author information"

  # Get defaults
  local default_name default_email
  default_name="${DEVBASE_GIT_AUTHOR:-$(git config --global user.name 2>/dev/null || echo "")}"
  [[ ! "$default_name" =~ $name_pattern ]] && default_name=""

  # Prompt for name with validation
  local git_name=""
  while true; do
    git_name=$(_gum_input "Firstname Lastname" "$default_name" "Your full name")
    if [[ "$git_name" =~ $name_pattern ]]; then
      break
    fi
    _gum_error "Please enter firstname and lastname (letters only)"
  done
  export DEVBASE_GIT_AUTHOR="$git_name"
  _gum_success "Name: $git_name"

  # Derive default email
  default_email="${DEVBASE_GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"
  if [[ ! "$default_email" =~ $email_pattern ]]; then
    default_email=$(_generate_default_email_from_name "$DEVBASE_GIT_AUTHOR" "${DEVBASE_EMAIL_DOMAIN:-}")
  fi

  # Prompt for email with validation
  local git_email=""
  while true; do
    git_email=$(_gum_input "you@example.com" "$default_email" "Your email address")
    # Auto-append domain if configured
    if [[ -n "${DEVBASE_EMAIL_DOMAIN:-}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
      [[ ! "$git_email" =~ @ ]] && git_email="${git_email}${DEVBASE_EMAIL_DOMAIN}"
    fi
    if [[ "$git_email" =~ $email_pattern ]]; then
      break
    fi
    _gum_error "Please enter a valid email address"
  done
  export DEVBASE_GIT_EMAIL="$git_email"
  _gum_success "Email: $git_email"
}

collect_theme_preference() {
  _gum_section "Theme Selection"

  local current="${DEVBASE_THEME:-everforest-dark}"

  # Theme data: "bg,fg,keyword,function,string,comment"
  local -A theme_colors=(
    ["everforest-dark"]="236,223,167,108,142,245"
    ["catppuccin-mocha"]="236,223,203,139,166,245"
    ["tokyonight-night"]="234,223,203,116,158,243"
    ["gruvbox-dark"]="235,223,167,108,142,245"
    ["nord"]="236,223,168,136,150,243"
    ["dracula"]="236,223,212,117,84,243"
    ["solarized-dark"]="235,223,168,37,106,241"
    ["everforest-light"]="230,235,124,66,107,245"
    ["catppuccin-latte"]="231,235,127,37,71,245"
    ["tokyonight-day"]="231,235,128,37,71,245"
    ["gruvbox-light"]="230,235,124,66,106,245"
    ["solarized-light"]="230,235,168,37,106,245"
  )

  # Brief descriptions
  local -A theme_desc=(
    ["everforest-dark"]="◐ Warm, soft"
    ["catppuccin-mocha"]="◐ Soothing pastel"
    ["tokyonight-night"]="◐ Clean, dark"
    ["gruvbox-dark"]="◐ Retro groove"
    ["nord"]="◐ Arctic, bluish"
    ["dracula"]="◐ Dark, vivid"
    ["solarized-dark"]="◐ Precision colors"
    ["everforest-light"]="◑ Warm, soft"
    ["catppuccin-latte"]="◑ Soothing pastel"
    ["tokyonight-day"]="◑ Clean, bright"
    ["gruvbox-light"]="◑ Retro groove"
    ["solarized-light"]="◑ Precision colors"
  )

  local -a themes=(
    everforest-dark catppuccin-mocha tokyonight-night gruvbox-dark
    nord dracula solarized-dark
    everforest-light catppuccin-latte tokyonight-day gruvbox-light solarized-light
  )

  # Build display options with theme name as prefix for extraction
  local -a options=()
  for theme in "${themes[@]}"; do
    local colors="${theme_colors[$theme]}"
    local desc="${theme_desc[$theme]}"
    IFS=',' read -r bg fg kw fn str cm <<<"$colors"

    # Build colorized code snippet with background (Go syntax)
    local preview
    preview=$(printf "\e[48;5;%sm \e[38;5;%sm// ok \e[38;5;%smfunc \e[38;5;%smMain\e[38;5;%sm() \e[38;5;%sm\"hi\" \e[0m" "$bg" "$cm" "$kw" "$fn" "$fg" "$str")

    local check=" "
    [[ "$theme" == "$current" ]] && check="✓"
    # Theme name is first, making extraction easy
    options+=("$(printf '%-18s %s %-20s %s' "$theme" "$check" "$desc" "$preview")")
  done

  local choice
  choice=$(
    gum choose \
      --header "Use Enter to select" \
      --no-show-help \
      --cursor "> " \
      --cursor.foreground "$_GUM_ACCENT" \
      --selected.foreground "$_GUM_ACCENT" \
      --height 14 \
      "${options[@]}"
  ) || _gum_exit_on_cancel_any

  # Theme name is the first field
  DEVBASE_THEME="${choice%% *}"
  [[ -z "${DEVBASE_THEME:-}" ]] && DEVBASE_THEME="everforest-dark"
  export DEVBASE_THEME

  _gum_success "Theme: $DEVBASE_THEME"
}

collect_font_preference() {
  # Skip on WSL - fonts managed by Windows Terminal
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    export DEVBASE_FONT=""
    return 0
  fi

  _gum_section "Font Selection"

  local current="${DEVBASE_FONT:-monaspace}"

  local -A font_info=(
    ["monaspace"]="Superfamily, multiple styles"
    ["jetbrains-mono"]="Clear, excellent readability"
    ["firacode"]="Popular, extensive ligatures"
    ["cascadia-code"]="Microsoft, Powerline glyphs"
  )

  local -a fonts=(monaspace jetbrains-mono firacode cascadia-code)

  # Build display options with font name as prefix for extraction
  local -a options=()
  for font in "${fonts[@]}"; do
    local check=" "
    [[ "$font" == "$current" ]] && check="✓"
    # Font name is first, making extraction easy
    options+=("$(printf '%-15s %s %s' "$font" "$check" "${font_info[$font]}")")
  done

  local choice
  choice=$(gum choose \
    --no-show-help \
    --cursor "> " \
    --cursor.foreground "$_GUM_ACCENT" \
    --selected.foreground "$_GUM_ACCENT" \
    "${options[@]}") || _gum_exit_on_cancel_any

  # Font name is the first field
  DEVBASE_FONT="${choice%% *}"
  [[ -z "${DEVBASE_FONT:-}" ]] && DEVBASE_FONT="monaspace"
  export DEVBASE_FONT

  _gum_success "Font: $DEVBASE_FONT"
}

collect_ssh_configuration() {
  validate_var_set "HOME" || return 1

  _gum_section "SSH Key Setup"
  _gum_help "Secure authentication for Git and remote servers"

  local ssh_key_path="$HOME/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"

  if [[ -f "$ssh_key_path" ]]; then
    _gum_success "SSH key exists: ${ssh_key_path/#$HOME/~}"
    echo
    if _gum_confirm "Generate a NEW key? (overwrites existing)" "negative"; then
      export DEVBASE_SSH_KEY_ACTION="new"
      _collect_ssh_passphrase
    else
      export DEVBASE_SSH_KEY_ACTION="keep"
      _gum_success "Keeping existing key"
    fi
  else
    _gum_help "No SSH key found at: ${ssh_key_path/#$HOME/~}"
    echo
    if _gum_confirm "Generate a new SSH key?"; then
      export DEVBASE_SSH_KEY_ACTION="new"
      _collect_ssh_passphrase
    else
      export DEVBASE_SSH_KEY_ACTION="skip"
      _gum_warning "Skipping SSH key generation"
    fi
  fi
}

_collect_ssh_passphrase() {
  local pass1 pass2

  echo
  _gum_help "Minimum 12 characters (NIST recommendation)"

  while true; do
    pass1=$(_gum_password "Enter passphrase" "SSH Key Passphrase")

    if [[ ${#pass1} -lt 12 ]]; then
      _gum_error "Passphrase must be at least 12 characters"
      continue
    fi

    pass2=$(_gum_password "Confirm passphrase")

    if [[ "$pass1" != "$pass2" ]]; then
      _gum_error "Passphrases don't match"
      continue
    fi

    break
  done

  export DEVBASE_SSH_PASSPHRASE="$pass1"
  _gum_success "Passphrase set"
}

collect_editor_preferences() {
  _gum_section "Editors & IDEs"

  # Build list with current selections
  local vscode_option
  if is_wsl; then
    vscode_option="VS Code Remote-WSL"
  else
    vscode_option="VS Code"
  fi
  local lazyvim_option="LazyVim (Neovim IDE)"
  local intellij_option="IntelliJ IDEA Ultimate ⚠ ~1GB"

  local options=("$vscode_option" "$lazyvim_option" "$intellij_option")

  # Pre-select VS Code and LazyVim by default (or based on current values)
  local preselected=""
  [[ "${DEVBASE_VSCODE_INSTALL:-true}" == "true" ]] && preselected+="${vscode_option},"
  [[ "${DEVBASE_INSTALL_LAZYVIM:-true}" == "true" ]] && preselected+="${lazyvim_option},"
  [[ "${DEVBASE_INSTALL_INTELLIJ:-false}" == "true" ]] && preselected+="${intellij_option},"
  preselected="${preselected%,}" # Remove trailing comma

  local selected
  selected=$(_gum_choose_multi "$preselected" "${options[@]}")

  # Parse selections
  export DEVBASE_VSCODE_INSTALL="false"
  export DEVBASE_INSTALL_LAZYVIM="false"
  export DEVBASE_INSTALL_INTELLIJ="false"

  if echo "$selected" | grep -q "VS Code"; then
    export DEVBASE_VSCODE_INSTALL="true"
    export DEVBASE_VSCODE_EXTENSIONS="true"
    _gum_success "VS Code"
  fi
  if echo "$selected" | grep -q "LazyVim"; then
    export DEVBASE_INSTALL_LAZYVIM="true"
    _gum_success "LazyVim"
  fi
  if echo "$selected" | grep -q "IntelliJ"; then
    export DEVBASE_INSTALL_INTELLIJ="true"
    _gum_success "IntelliJ IDEA"
  fi

  if [[ "${DEVBASE_VSCODE_INSTALL}" == "false" ]]; then
    export DEVBASE_VSCODE_EXTENSIONS="false"
  fi
}

collect_tool_preferences() {
  _gum_section "Shell & Tools"

  # Build binding options (single-choice via multi-select)
  local current_binding="vim"
  [[ "${EDITOR:-}" == "nano" ]] && current_binding="emacs"

  local -a options=(
    "Vim-style - Modal editing / hjkl navigation"
    "Emacs-style - Arrow keys / Ctrl shortcuts"
  )

  local preselected=""
  [[ "$current_binding" == "vim" ]] && preselected="${options[0]}" || preselected="${options[1]}"

  local selected_binding=""
  local header=""
  while [[ -z "$selected_binding" ]]; do
    local choice
    GUM_CHOOSE_HEADER="$header" choice=$(_gum_choose_multi "$preselected" "${options[@]}")

    local count
    count=$(echo "$choice" | grep -c .)
    if [[ $count -ne 1 ]]; then
      header="Select exactly one binding"
      continue
    fi

    selected_binding=$(echo "$choice" | awk '{print $1}')
    header=""
  done

  if [[ "$selected_binding" == "Vim-style" ]]; then
    export EDITOR="nvim"
    export VISUAL="nvim"
    _gum_success "Vim bindings, editor: nvim"
  else
    export EDITOR="nano"
    export VISUAL="nano"
    _gum_success "Emacs bindings, editor: nano"
  fi

  echo

  local zellij_option="Zellij (autostart terminal multiplexer)"
  local hooks_option="Git hooks (commit-msg / pre-commit / etc.)"
  local jmc_option="JDK Mission Control ⚠ ~1GB"

  local tools=("$zellij_option" "$hooks_option" "$jmc_option")

  # Pre-select Zellij and Git hooks by default
  local preselected=""
  [[ "${DEVBASE_ZELLIJ_AUTOSTART:-true}" == "true" ]] && preselected+="${zellij_option},"
  [[ "${DEVBASE_ENABLE_GIT_HOOKS:-true}" == "true" ]] && preselected+="${hooks_option},"
  [[ "${DEVBASE_INSTALL_JMC:-false}" == "true" ]] && preselected+="${jmc_option},"
  preselected="${preselected%,}"

  local selected
  selected=$(_gum_choose_multi "$preselected" "${tools[@]}")

  # Default all to false, then enable selected
  export DEVBASE_ZELLIJ_AUTOSTART="false"
  export DEVBASE_ENABLE_GIT_HOOKS="false"
  export DEVBASE_INSTALL_JMC="false"

  if echo "$selected" | grep -q "Zellij"; then
    export DEVBASE_ZELLIJ_AUTOSTART="true"
    _gum_success "Zellij auto-start"
  fi
  if echo "$selected" | grep -qi "git hooks"; then
    export DEVBASE_ENABLE_GIT_HOOKS="true"
    _gum_success "Git hooks enabled"
  fi
  if echo "$selected" | grep -q "JDK Mission"; then
    export DEVBASE_INSTALL_JMC="true"
    _gum_success "JDK Mission Control"
  fi
}

collect_pack_preferences() {
  _gum_section "Language Packs"

  # Source parser if needed
  if ! declare -f get_available_packs &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser"
  fi

  # Get available packs
  local packs=() descriptions=() items=()
  while IFS='|' read -r pack desc; do
    packs+=("$pack")
    descriptions+=("$desc")
    items+=("$pack - $desc")
  done < <(get_available_packs)

  # Pre-select based on saved preferences, or all packs (except rust) if none saved
  local default_packs=()
  for pack in "${packs[@]}"; do
    [[ "$pack" == "rust" ]] && continue
    default_packs+=("$pack")
  done
  local preselected=""
  local saved_packs=" ${DEVBASE_SELECTED_PACKS:-${default_packs[*]}} "
  for i in "${!packs[@]}"; do
    if [[ "$saved_packs" == *" ${packs[$i]} "* ]]; then
      preselected+="${items[$i]},"
    fi
  done
  preselected="${preselected%,}"

  local selected
  selected=$(_gum_choose_multi "$preselected" "${items[@]}")

  # Extract pack names from selection
  DEVBASE_SELECTED_PACKS=""
  for pack in "${packs[@]}"; do
    if echo "$selected" | grep -q "^$pack "; then
      DEVBASE_SELECTED_PACKS+="$pack "
      _gum_success "$pack"
    fi
  done

  # Trim trailing space
  DEVBASE_SELECTED_PACKS="${DEVBASE_SELECTED_PACKS% }"

  # Default to all (except rust) if nothing selected
  if [[ -z "$DEVBASE_SELECTED_PACKS" ]]; then
    DEVBASE_SELECTED_PACKS="${default_packs[*]}"
    _gum_warning "No packs selected, defaulting to all except rust"
  fi

  export DEVBASE_SELECTED_PACKS
}

_show_configuration_summary() {
  echo
  _gum_header "Configuration Summary"
  echo

  # Build checkmarks
  local vs lv ij jmc zj gh
  [[ "${DEVBASE_VSCODE_INSTALL}" == "true" ]] && vs="✓" || vs="·"
  [[ "${DEVBASE_INSTALL_LAZYVIM}" == "true" ]] && lv="✓" || lv="·"
  [[ "${DEVBASE_INSTALL_INTELLIJ}" == "true" ]] && ij="✓" || ij="·"
  [[ "${DEVBASE_INSTALL_JMC}" == "true" ]] && jmc="✓" || jmc="·"
  [[ "${DEVBASE_ZELLIJ_AUTOSTART}" == "true" ]] && zj="✓" || zj="·"
  [[ "${DEVBASE_ENABLE_GIT_HOOKS}" == "true" ]] && gh="✓" || gh="·"

  # Detect clipboard utility
  local clipboard="none"
  if command -v wl-copy &>/dev/null; then
    clipboard="wl-copy"
  elif command -v xclip &>/dev/null; then
    clipboard="xclip"
  elif command -v xsel &>/dev/null; then
    clipboard="xsel"
  fi

  # Shell bindings
  local bindings="Emacs-style"
  [[ "$EDITOR" == "nvim" ]] && bindings="Vim-style"

  gum style --foreground "$_GUM_SUBTLE" "Git"
  echo "  Name:  $DEVBASE_GIT_AUTHOR"
  echo "  Email: $DEVBASE_GIT_EMAIL"
  echo

  gum style --foreground "$_GUM_SUBTLE" "Appearance"
  echo "  Theme: $DEVBASE_THEME"
  [[ "${_DEVBASE_ENV:-}" != "wsl-ubuntu" ]] && echo "  Font:  ${DEVBASE_FONT:-monaspace}"
  echo

  gum style --foreground "$_GUM_SUBTLE" "SSH Key"
  if [[ "${DEVBASE_SSH_KEY_ACTION}" == "new" ]]; then
    echo "  Action:   Generate new key"
    echo "  Location: ~/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"
  elif [[ "${DEVBASE_SSH_KEY_ACTION}" == "skip" ]]; then
    echo "  Action:   Skip (no SSH key)"
  else
    echo "  Action:   Keep existing key"
    echo "  Location: ~/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"
  fi
  echo

  gum style --foreground "$_GUM_SUBTLE" "Editor & Shell"
  echo "  Default editor:  $EDITOR"
  echo "  Shell bindings:  $bindings"
  echo "  Clipboard:       $clipboard"
  echo

  gum style --foreground "$_GUM_SUBTLE" "IDEs"
  echo "  $vs VS Code    $lv LazyVim    $ij IntelliJ"
  echo

  gum style --foreground "$_GUM_SUBTLE" "Tools"
  echo "  $zj Zellij    $gh Git hooks    $jmc JMC"
  echo

  gum style --foreground "$_GUM_SUBTLE" "Language Packs"
  echo "  ${DEVBASE_SELECTED_PACKS// /, }"
  echo

  # Show installation overview
  gum style --foreground "$_GUM_SUBTLE" "Installation"
  echo "  Estimated time: 10-15 minutes"
  echo "  Disk space:     ~6GB required"
  echo "  Sudo password will be requested"
  echo

  if _gum_confirm "Proceed with installation?"; then
    return 0
  fi
  return 1
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

collect_user_configuration() {
  # Non-interactive mode
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    setup_non_interactive_mode
    return 0
  fi

  # Check gum availability
  if ! command -v gum &>/dev/null; then
    echo "ERROR: gum is required but not found." >&2
    return 1
  fi

  # Load saved preferences as defaults
  load_saved_preferences || true

  # Collect all preferences
  collect_git_configuration
  collect_theme_preference
  collect_font_preference
  collect_ssh_configuration
  collect_editor_preferences
  collect_tool_preferences
  collect_pack_preferences

  # Show summary and confirm
  while ! _show_configuration_summary; do
    echo
    if _gum_confirm "Modify your configuration?"; then
      collect_git_configuration
      collect_theme_preference
      collect_font_preference
      collect_ssh_configuration
      collect_editor_preferences
      collect_tool_preferences
      collect_pack_preferences
    else
      echo "Setup cancelled."
      exit 1
    fi
  done

  # Write preferences
  write_user_preferences

  return 0
}

# =============================================================================
# UI-SPECIFIC SUCCESS WRAPPER
# =============================================================================

# This function is called by write_user_preferences in common.sh
_ui_success() {
  _gum_success "$1"
}
