#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Whiptail-based TUI for DevBase setup
# Alternative to collect-user-preferences.sh using dialog boxes

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Source common functions shared with gum implementation
# shellcheck source=collect-user-preferences-common.sh
source "${DEVBASE_ROOT}/libs/collect-user-preferences-common.sh"

# =============================================================================
# WHIPTAIL CONFIGURATION
# =============================================================================

# Calculate terminal dimensions (leave margin for borders)
_WT_TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
_WT_TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
_WT_HEIGHT=$((_WT_TERM_HEIGHT - 4))
_WT_WIDTH=$((_WT_TERM_WIDTH - 4))
# Clamp to reasonable bounds
((_WT_HEIGHT > 30)) && _WT_HEIGHT=30
((_WT_HEIGHT < 15)) && _WT_HEIGHT=15
((_WT_WIDTH > 78)) && _WT_WIDTH=78
((_WT_WIDTH < 50)) && _WT_WIDTH=50
_WT_LIST_HEIGHT=$((_WT_HEIGHT - 8))

# Navigation hints (kept for backward compatibility, but backtitle is preferred)
# WT_BACKTITLE is defined in ui-helpers-whiptail.sh (already sourced)
_WT_NAV_HINTS=""

# =============================================================================
# WHIPTAIL PRIMITIVES
# =============================================================================

# Brief: Check if whiptail is available
_check_whiptail() {
  command -v whiptail &>/dev/null
}

# Brief: Display a message box
# Params: $1 - title, $2 - message
_wt_msgbox() {
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$1" \
    --msgbox "$2" \
    "$_WT_HEIGHT" "$_WT_WIDTH"
}

# Brief: Display a yes/no dialog
# Params: $1 - title, $2 - message, $3 - default (yes/no)
# Returns: 0 for yes, 1 for no
_wt_yesno() {
  local title="$1" message="$2" default="${3:-yes}"
  local opts=(--backtitle "$WT_BACKTITLE" --title "$title")
  [[ "$default" == "no" ]] && opts+=(--defaultno)
  opts+=(--yesno "$message" "$_WT_HEIGHT" "$_WT_WIDTH")
  whiptail "${opts[@]}"
}

# Brief: Display an input box
# Params: $1 - title, $2 - message, $3 - default value
# Outputs: User input to stdout
# Returns: 0 on OK, 1 on Cancel
_wt_input() {
  local title="$1" message="$2" default="${3:-}"
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" \
    --inputbox "$message" \
    "$_WT_HEIGHT" "$_WT_WIDTH" "$default" \
    3>&1 1>&2 2>&3
}

# Brief: Display a password box
# Params: $1 - title, $2 - message
# Outputs: Password to stdout
# Returns: 0 on OK, 1 on Cancel
_wt_password() {
  local title="$1" message="$2"
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" \
    --passwordbox "$message" \
    "$_WT_HEIGHT" "$_WT_WIDTH" \
    3>&1 1>&2 2>&3
}

# Brief: Display a menu (single selection)
# Params: $1 - title, $2 - message, $3 - default item, $@ - tag/description pairs
# Outputs: Selected tag to stdout
# Returns: 0 on OK, 1 on Cancel
_wt_menu() {
  local title="$1" message="$2${_WT_NAV_HINTS}" default="$3"
  shift 3
  local opts=(--backtitle "$WT_BACKTITLE" --title "$title")
  [[ -n "$default" ]] && opts+=(--default-item "$default")
  opts+=(--menu "$message" "$_WT_HEIGHT" "$_WT_WIDTH" "$_WT_LIST_HEIGHT")
  whiptail "${opts[@]}" "$@" 3>&1 1>&2 2>&3
}

# Brief: Display a checklist (multiple selection)
# Params: $1 - title, $2 - message, $@ - tag/description/status triplets
# Outputs: Selected tags (one per line) to stdout
# Returns: 0 on OK, 1 on Cancel
_wt_checklist() {
  local title="$1" message="$2${_WT_NAV_HINTS}"
  shift 2
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" \
    --separate-output \
    --checklist "$message" \
    "$_WT_HEIGHT" "$_WT_WIDTH" "$_WT_LIST_HEIGHT" \
    "$@" 3>&1 1>&2 2>&3
}

# Brief: Display a radiolist (single selection from list)
# Params: $1 - title, $2 - message, $@ - tag/description/status triplets
# Outputs: Selected tag to stdout
# Returns: 0 on OK, 1 on Cancel
_wt_radiolist() {
  local title="$1" message="$2${_WT_NAV_HINTS}"
  shift 2
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" \
    --radiolist "$message" \
    "$_WT_HEIGHT" "$_WT_WIDTH" "$_WT_LIST_HEIGHT" \
    "$@" 3>&1 1>&2 2>&3
}

# Brief: Display a scrollable text box with yes/no buttons
# Params: $1 - title, $2 - text content
# Returns: 0 for yes, 1 for no
_wt_scrollable_yesno() {
  local title="$1" content="$2"
  local tmpfile
  tmpfile=$(mktemp)
  echo "$content" >"$tmpfile"

  # Use --textbox would be read-only, so we use --yesno with --scrolltext
  whiptail --backtitle "$WT_BACKTITLE" \
    --title "$title" \
    --scrolltext \
    --yesno "$(cat "$tmpfile")" \
    "$_WT_HEIGHT" "$_WT_WIDTH"
  local result=$?
  rm -f "$tmpfile"
  return $result
}

# Brief: Handle user cancellation
# Shows a confirmation dialog and exits if user confirms
_handle_cancel() {
  if _wt_yesno "Cancel Setup" "Are you sure you want to cancel the setup?" "no"; then
    # Silent exit in whiptail mode - the dialog already confirmed
    exit 1
  fi
}

# =============================================================================
# COLLECTION FUNCTIONS - WHIPTAIL UI
# =============================================================================

collect_git_configuration() {
  local name_pattern='^[[:alpha:]]+[[:space:]]+[[:alpha:]]+$'
  local email_pattern='^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  # Get defaults
  local default_name default_email
  default_name="${DEVBASE_GIT_AUTHOR:-$(git config --global user.name 2>/dev/null || echo "")}"
  [[ ! "$default_name" =~ $name_pattern ]] && default_name=""

  # Prompt for name with validation
  local git_name=""
  while true; do
    if ! git_name=$(_wt_input "Git Configuration" \
      "Enter your full name (firstname lastname):\n\nThis will be used for git commits." \
      "$default_name"); then
      _handle_cancel
      continue
    fi
    if [[ "$git_name" =~ $name_pattern ]]; then
      break
    fi
    _wt_msgbox "Validation Error" "Please enter firstname and lastname separated by a space.\n\nExample: John Doe"
  done
  export DEVBASE_GIT_AUTHOR="$git_name"

  # Derive default email
  default_email="${DEVBASE_GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"
  if [[ ! "$default_email" =~ $email_pattern ]]; then
    default_email=$(_generate_default_email_from_name "$DEVBASE_GIT_AUTHOR" "${DEVBASE_EMAIL_DOMAIN:-}")
  fi

  # Prompt for email with validation
  local git_email=""
  while true; do
    if ! git_email=$(_wt_input "Git Configuration" \
      "Enter your email address:\n\nThis will be used for git commits." \
      "$default_email"); then
      _handle_cancel
      continue
    fi
    # Auto-append domain if configured
    if [[ -n "${DEVBASE_EMAIL_DOMAIN:-}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
      [[ ! "$git_email" =~ @ ]] && git_email="${git_email}${DEVBASE_EMAIL_DOMAIN}"
    fi
    if [[ "$git_email" =~ $email_pattern ]]; then
      break
    fi
    _wt_msgbox "Validation Error" "Please enter a valid email address.\n\nExample: firstname.lastname@example.com"
  done
  export DEVBASE_GIT_EMAIL="$git_email"
}

collect_theme_preference() {
  local current="${DEVBASE_THEME:-everforest-dark}"

  # Build radiolist items - mark current as selected
  local items=()
  local themes=(
    "everforest-dark:◐ Soft warm greens, easy on eyes"
    "catppuccin-mocha:◐ Pastel colors, cozy modern feel"
    "tokyonight-night:◐ Vibrant neon blues and purples"
    "gruvbox-dark:◐ Retro warm oranges and yellows"
    "nord:◐ Arctic blues, cool and elegant"
    "dracula:◐ Purple and pink, popular choice"
    "solarized-dark:◐ Precision engineered colors"
    "everforest-light:◑ Soft warm greens, comfortable"
    "catppuccin-latte:◑ Pastel colors, gentle on eyes"
    "tokyonight-day:◑ Clean bright blues"
    "gruvbox-light:◑ Retro warm, high readability"
    "solarized-light:◑ Precision engineered colors"
  )

  for entry in "${themes[@]}"; do
    local tag="${entry%%:*}"
    local desc="${entry#*:}"
    local status="OFF"
    [[ "$tag" == "$current" ]] && status="ON"
    items+=("$tag" "$desc" "$status")
  done

  local choice
  if ! choice=$(_wt_radiolist "Theme Selection" \
    "
  Select a color theme for your terminal,
  editors, and development tools.

  ◐ = Dark theme    ◑ = Light theme

  Tip: Change anytime with devbase-theme
" \
    "${items[@]}"); then
    _handle_cancel
    collect_theme_preference
    return
  fi

  export DEVBASE_THEME="${choice:-everforest-dark}"
}

collect_font_preference() {
  # Skip on WSL - fonts managed by Windows Terminal
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    export DEVBASE_FONT=""
    return 0
  fi

  local current="${DEVBASE_FONT:-monaspace}"
  local items=()
  local fonts=(
    "monaspace:Superfamily, multiple styles"
    "jetbrains-mono:Clear, excellent readability"
    "firacode:Popular, extensive ligatures"
    "cascadia-code:Microsoft, Powerline glyphs"
  )

  for entry in "${fonts[@]}"; do
    local tag="${entry%%:*}"
    local desc="${entry#*:}"
    local status="OFF"
    [[ "$tag" == "$current" ]] && status="ON"
    items+=("$tag" "$desc" "$status")
  done

  local choice
  if ! choice=$(_wt_radiolist "Font Selection" \
    "
  Select a Nerd Font for your terminal
  and code editors.

  All fonts include:
    • Programming ligatures
    • Powerline symbols
    • Dev icons
" \
    "${items[@]}"); then
    _handle_cancel
    collect_font_preference
    return
  fi

  export DEVBASE_FONT="${choice:-monaspace}"
}

collect_ssh_configuration() {
  validate_var_set "HOME" || return 1
  local ssh_key_path="$HOME/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"

  if [[ -f "$ssh_key_path" ]]; then
    # Existing key
    if _wt_yesno "SSH Key Setup" \
      "An SSH key already exists:\n${ssh_key_path}\n\nDo you want to generate a NEW key?\n(This will overwrite the existing key)" \
      "no"; then
      export DEVBASE_SSH_KEY_ACTION="new"
      _collect_ssh_passphrase
    else
      export DEVBASE_SSH_KEY_ACTION="keep"
    fi
  else
    # No existing key
    if _wt_yesno "SSH Key Setup" \
      "No DevBase SSH key found.\n\nSSH keys provide secure authentication for Git and remote servers.\n\nGenerate a new SSH key?" \
      "yes"; then
      export DEVBASE_SSH_KEY_ACTION="new"
      _collect_ssh_passphrase
    else
      export DEVBASE_SSH_KEY_ACTION="skip"
    fi
  fi
}

_collect_ssh_passphrase() {
  local pass1 pass2
  while true; do
    if ! pass1=$(_wt_password "SSH Key Passphrase" \
      "Enter a passphrase to protect your SSH key.\n\nMinimum 12 characters (NIST recommendation)."); then
      _handle_cancel
      continue
    fi
    if [[ ${#pass1} -lt 12 ]]; then
      _wt_msgbox "Validation Error" "Passphrase must be at least 12 characters.\n\nThis is a security requirement per NIST guidelines."
      continue
    fi
    if ! pass2=$(_wt_password "SSH Key Passphrase" "Confirm your passphrase:"); then
      _handle_cancel
      continue
    fi
    if [[ "$pass1" != "$pass2" ]]; then
      _wt_msgbox "Validation Error" "Passphrases do not match.\n\nPlease try again."
      continue
    fi
    break
  done
  export DEVBASE_SSH_PASSPHRASE="$pass1"
}

collect_editor_preferences() {
  # Build checklist with current selections
  local items=()

  # VS Code
  local vscode_default="ON"
  [[ "${DEVBASE_VSCODE_INSTALL:-true}" == "false" ]] && vscode_default="OFF"
  if is_wsl; then
    items+=("vscode" "VS Code Remote-WSL" "$vscode_default")
  else
    items+=("vscode" "VS Code" "$vscode_default")
  fi

  # LazyVim
  local lazyvim_default="ON"
  [[ "${DEVBASE_INSTALL_LAZYVIM:-true}" == "false" ]] && lazyvim_default="OFF"
  items+=("lazyvim" "LazyVim (Neovim IDE)" "$lazyvim_default")

  # IntelliJ
  local intellij_default="OFF"
  [[ "${DEVBASE_INSTALL_INTELLIJ:-false}" == "true" ]] && intellij_default="ON"
  items+=("intellij" "IntelliJ IDEA Ultimate ⚠ ~1GB" "$intellij_default")

  local selected
  if ! selected=$(_wt_checklist "Editors & IDEs" \
    "Select editors and IDEs to install." \
    "${items[@]}"); then
    _handle_cancel
    collect_editor_preferences
    return
  fi

  # Parse selections
  export DEVBASE_VSCODE_INSTALL="false"
  export DEVBASE_INSTALL_LAZYVIM="false"
  export DEVBASE_INSTALL_INTELLIJ="false"

  while IFS= read -r item; do
    case "$item" in
    vscode)
      export DEVBASE_VSCODE_INSTALL="true"
      export DEVBASE_VSCODE_EXTENSIONS="true"
      ;;
    lazyvim) export DEVBASE_INSTALL_LAZYVIM="true" ;;
    intellij) export DEVBASE_INSTALL_INTELLIJ="true" ;;
    esac
  done <<<"$selected"

  # If VS Code not selected, disable extensions
  if [[ "${DEVBASE_VSCODE_INSTALL}" == "false" ]]; then
    export DEVBASE_VSCODE_EXTENSIONS="false"
  fi
}

collect_tool_preferences() {
  # Shell bindings - radiolist
  local current_editor="${EDITOR:-nvim}"
  local vim_status="ON" emacs_status="OFF"
  [[ "$current_editor" != "nvim" ]] && vim_status="OFF" && emacs_status="ON"

  local editor_choice
  while true; do
    if ! editor_choice=$(_wt_checklist "Shell Key Bindings" \
      "
  Choose key bindings for command line editing.

  Vim:   Modal editing, hjkl navigation
         ESC to command mode, i to insert

  Emacs: Arrow keys, Ctrl shortcuts
         Ctrl-A start, Ctrl-E end

  Use Space to toggle, Enter to confirm.
 " \
      "vim" "Modal editing, hjkl navigation" "$vim_status" \
      "emacs" "Arrow keys, Ctrl shortcuts" "$emacs_status"); then
      _handle_cancel
      collect_tool_preferences
      return
    fi

    local count
    count=$(echo "$editor_choice" | grep -c .)
    if [[ $count -eq 1 ]]; then
      break
    fi

    _wt_msgbox "Shell Key Bindings" "Select exactly one option."
  done

  if [[ "$editor_choice" == "vim" ]]; then
    export EDITOR="nvim"
    export VISUAL="nvim"
  else
    export EDITOR="nano"
    export VISUAL="nano"
  fi

  # Tool options checklist
  local items=()

  # JMC
  local jmc_default="OFF"
  [[ "${DEVBASE_INSTALL_JMC:-false}" == "true" ]] && jmc_default="ON"
  # Zellij autostart
  local zellij_default="ON"
  [[ "${DEVBASE_ZELLIJ_AUTOSTART:-true}" == "false" ]] && zellij_default="OFF"
  items+=("zellij" "Zellij auto-start (terminal multiplexer)" "$zellij_default")

  # Git hooks
  local hooks_default="ON"
  [[ "${DEVBASE_ENABLE_GIT_HOOKS:-true}" == "false" ]] && hooks_default="OFF"
  items+=("githooks" "Global git hooks (pre-commit checks)" "$hooks_default")

  # JMC
  items+=("jmc" "JDK Mission Control ⚠ ~1GB" "$jmc_default")

  local selected
  if ! selected=$(_wt_checklist "Additional Tools" \
    "Configure additional development tools.\n\nUse Space to toggle, Enter to confirm." \
    "${items[@]}"); then
    _handle_cancel
    collect_tool_preferences
    return
  fi

  # Parse selections - default all to false, then enable selected
  export DEVBASE_INSTALL_JMC="false"
  export DEVBASE_ZELLIJ_AUTOSTART="false"
  export DEVBASE_ENABLE_GIT_HOOKS="false"

  while IFS= read -r item; do
    case "$item" in
    jmc) export DEVBASE_INSTALL_JMC="true" ;;
    zellij) export DEVBASE_ZELLIJ_AUTOSTART="true" ;;
    githooks) export DEVBASE_ENABLE_GIT_HOOKS="true" ;;
    esac
  done <<<"$selected"
}

collect_pack_preferences() {
  # Show loading indicator while preparing dialog
  _wt_infobox "Language Packs" "Loading available packs..."

  # Source parser if needed
  if ! declare -f get_available_packs &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser"
  fi

  # Get available packs
  local packs=() descriptions=()
  while IFS='|' read -r pack desc; do
    packs+=("$pack")
    descriptions+=("$desc")
  done < <(get_available_packs)

  # Current selection (space-separated) - default to all except rust
  local default_packs=()
  for pack in "${packs[@]}"; do
    [[ "$pack" == "rust" ]] && continue
    default_packs+=("$pack")
  done
  local current_selection=" ${DEVBASE_SELECTED_PACKS:-${default_packs[*]}} "

  # Build checklist
  local items=()
  for i in "${!packs[@]}"; do
    local pack="${packs[$i]}"
    local desc="${descriptions[$i]}"
    local status="OFF"
    [[ "$current_selection" == *" $pack "* ]] && status="ON"
    items+=("$pack" "$desc" "$status")
  done

  local selected
  if ! selected=$(_wt_checklist "Language Packs" \
    "Select language packs to install.

  Each pack includes:
    • Language runtime (via mise)
    • Build tools & linters
    • Editor extensions" \
    "${items[@]}"); then
    _handle_cancel
    collect_pack_preferences
    return
  fi

  # Convert newline-separated to space-separated
  DEVBASE_SELECTED_PACKS=$(echo "$selected" | tr '\n' ' ' | sed 's/ $//')

  # Default to all except rust if nothing selected
  [[ -z "$DEVBASE_SELECTED_PACKS" ]] && DEVBASE_SELECTED_PACKS="${default_packs[*]}"
  export DEVBASE_SELECTED_PACKS
}

_show_configuration_summary() {
  # Build a nicely formatted summary
  local vs lv ij jmc zj gh
  vs="$(_bool_to_symbol "${DEVBASE_VSCODE_INSTALL}")"
  lv="$(_bool_to_symbol "${DEVBASE_INSTALL_LAZYVIM}")"
  ij="$(_bool_to_symbol "${DEVBASE_INSTALL_INTELLIJ}")"
  jmc="$(_bool_to_symbol "${DEVBASE_INSTALL_JMC}")"
  zj="$(_bool_to_symbol "${DEVBASE_ZELLIJ_AUTOSTART}")"
  gh="$(_bool_to_symbol "${DEVBASE_ENABLE_GIT_HOOKS}")"

  local packs_formatted="${DEVBASE_SELECTED_PACKS// /, }"
  local font_display="${DEVBASE_FONT:-N/A (WSL)}"

  # Truncate long values to fit in box (max 40 chars for values)
  local git_name="${DEVBASE_GIT_AUTHOR:0:40}"
  local git_email="${DEVBASE_GIT_EMAIL:0:40}"
  local packs_display="${packs_formatted:0:45}"
  [[ ${#packs_formatted} -gt 45 ]] && packs_display="${packs_display}..."

  local summary
  summary="
   ╔═══════════════════════════════════════════════════╗
   ║           CONFIGURATION SUMMARY                   ║
   ╚═══════════════════════════════════════════════════╝
                                        (↑↓ to scroll)

   Git
   ├─ Name    ${git_name}
   └─ Email   ${git_email}

   Appearance
   ├─ Theme   ${DEVBASE_THEME}
   └─ Font    ${font_display}

   SSH Key
   └─ Action  ${DEVBASE_SSH_KEY_ACTION}

   Editors & IDEs
   └─ ${vs} VS Code   ${lv} LazyVim   ${ij} IntelliJ

   Tools
   ├─ Editor  ${EDITOR}
   └─ ${jmc} JMC   ${zj} Zellij   ${gh} Git Hooks

   Language Packs
   └─ ${packs_display}
"

  if ! _wt_scrollable_yesno "Review Configuration" "$summary"; then
    return 1
  fi
  return 0
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

  # Check whiptail availability
  if ! _check_whiptail; then
    # Can't use whiptail to show this error since it's not installed
    printf "ERROR: whiptail is required for TUI mode but not found.\n" >&2
    printf "Install with: sudo apt install whiptail\n" >&2
    return 1
  fi

  # Clear any accumulated log from pre-flight checks
  _wt_clear_log

  # Show loading infobox immediately to prevent terminal flicker
  _wt_infobox "DevBase Core" "Loading configuration..."

  # Load saved preferences as defaults
  load_saved_preferences || true

  # Get version info
  local git_tag git_sha devbase_version
  git_tag=$(git -C "${DEVBASE_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")
  git_sha=$(git -C "${DEVBASE_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  devbase_version="${git_tag:-0.0.0-dev}"

  # Welcome message with version - pad version to fit box width
  local version_str="Version: ${devbase_version} (${git_sha})"
  # Pad to 37 chars to align with box (39 chars inner width - 2 for spacing)
  local padded_version
  padded_version=$(printf "%-37s" "$version_str")

  _wt_msgbox "Welcome to DevBase" \
    "
       ╔═══════════════════════════════════════╗
       ║           D E V B A S E               ║
       ║     Development Environment Setup     ║
       ╠═══════════════════════════════════════╣
       ║ ${padded_version} ║
       ╚═══════════════════════════════════════╝

   This wizard will configure your development
   environment with:

     • Git configuration
     • Theme and font preferences
     • SSH key setup
     • Editors and IDEs
     • Development tools
     • Language packs

   Press Esc or Ctrl+C to cancel at any time.
"

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
    # User wants to make changes - restart collection
    if _wt_yesno "Modify Configuration" "Would you like to modify your configuration?" "yes"; then
      collect_git_configuration
      collect_theme_preference
      collect_font_preference
      collect_ssh_configuration
      collect_editor_preferences
      collect_tool_preferences
      collect_pack_preferences
    else
      _handle_cancel
    fi
  done

  # Show transitional infobox to prevent flicker before installation gauge starts
  _wt_infobox "Starting Installation" "Preparing to install..."

  # Write preferences
  write_user_preferences

  return 0
}

# =============================================================================
# UI-SPECIFIC SUCCESS WRAPPER
# =============================================================================

# This function is called by write_user_preferences in common.sh
_ui_success() {
  show_progress success "$1"
}
