#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Setup defaults for non-interactive installation mode
# Params: None
# Uses: SSH_KEY_PASSPHRASE, DEVBASE_COLORS, DEVBASE_CONFIG_DIR, USER, hostname (globals)
# Modifies: Exports multiple DEVBASE_* environment variables
# Returns: 0 always (implicit)
# Side-effects: Generates SSH passphrase, creates config dir, writes temp file, prints config summary
setup_non_interactive_mode() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1
  validate_var_set "USER" || return 1

  printf "\n"
  printf "%bRunning in non-interactive mode with defaults...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"

  #TODO: DO We really need both of thes vars, why cant we just use DEVBASE_SSH_PASSPHRASE directly
  # Map SSH_KEY_PASSPHRASE (user-facing) to DEVBASE_SSH_PASSPHRASE (internal)
  if [[ -z "$SSH_KEY_PASSPHRASE" ]]; then
    DEVBASE_SSH_PASSPHRASE="$(generate_ssh_passphrase)"
  else
    DEVBASE_SSH_PASSPHRASE="$SSH_KEY_PASSPHRASE"
  fi
  export DEVBASE_SSH_PASSPHRASE

  # If passphrase was auto-generated (user didn't provide SSH_KEY_PASSPHRASE)
  if [[ -z "${SSH_KEY_PASSPHRASE:-}" ]]; then
    export GENERATED_SSH_PASSPHRASE="true"
    mkdir -p "${DEVBASE_CONFIG_DIR}"
    echo "$DEVBASE_SSH_PASSPHRASE" >"${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
    chmod 600 "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
  fi

  validate_var_set "GIT_NAME" || return 1
  validate_var_set "GIT_EMAIL" || return 1
  # shellcheck disable=SC2153 # GIT_NAME/GIT_EMAIL validated above, set in setup.sh
  export DEVBASE_GIT_AUTHOR="${GIT_NAME}"
  # shellcheck disable=SC2153 # GIT_EMAIL validated above, set in setup.sh
  export DEVBASE_GIT_EMAIL="${GIT_EMAIL}"
  export DEVBASE_THEME="${DEVBASE_THEME}"
  export DEVBASE_INSTALL_DEVTOOLS="$DEVBASE_INSTALL_DEVTOOLS"
  export DEVBASE_INSTALL_LAZYVIM="$DEVBASE_INSTALL_LAZYVIM"

  # Set VS Code installation based on environment
  # WSL: Skip (should be installed on Windows side)
  # Native Ubuntu: Install by default
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    [[ -z "$DEVBASE_VSCODE_INSTALL" ]] && DEVBASE_VSCODE_INSTALL="false"
  else
    [[ -z "$DEVBASE_VSCODE_INSTALL" ]] && DEVBASE_VSCODE_INSTALL="true"
  fi
  export DEVBASE_VSCODE_INSTALL

  # Set VS Code extensions defaults based on whether VS Code is being installed
  if [[ "${DEVBASE_VSCODE_INSTALL}" == "true" ]]; then
    [[ -z "$DEVBASE_VSCODE_EXTENSIONS" ]] && DEVBASE_VSCODE_EXTENSIONS="true"
    [[ -z "$DEVBASE_VSCODE_NEOVIM" ]] && DEVBASE_VSCODE_NEOVIM="true"
  else
    [[ -z "$DEVBASE_VSCODE_EXTENSIONS" ]] && DEVBASE_VSCODE_EXTENSIONS="false"
    [[ -z "$DEVBASE_VSCODE_NEOVIM" ]] && DEVBASE_VSCODE_NEOVIM="false"
  fi
  export DEVBASE_VSCODE_EXTENSIONS
  export DEVBASE_VSCODE_NEOVIM

  [[ -z "$DEVBASE_SSH_KEY_ACTION" ]] && DEVBASE_SSH_KEY_ACTION="new"
  export DEVBASE_SSH_KEY_ACTION
  export DEVBASE_ZELLIJ_AUTOSTART
  export DEVBASE_ENABLE_GIT_HOOKS
  export DEVBASE_INSTALL_INTELLIJ
  export DEVBASE_INSTALL_JMC

  # All packs selected by default in non-interactive mode
  [[ -z "$DEVBASE_SELECTED_PACKS" ]] && DEVBASE_SELECTED_PACKS="java node python go ruby rust vscode-editor"
  export DEVBASE_SELECTED_PACKS

  printf "  Git Name: %s\n" "$DEVBASE_GIT_AUTHOR"
  printf "  Git Email: %s\n" "$DEVBASE_GIT_EMAIL"
  printf "  Theme: %s\n" "$DEVBASE_THEME"
  printf "  Packs: %s\n" "$DEVBASE_SELECTED_PACKS"
  if [[ "$GENERATED_SSH_PASSPHRASE" == "true" ]]; then
    printf "  SSH Key: Generated with secure passphrase\n"
  fi
}

# Brief: Load saved preferences from previous installation
# Params: None
# Uses: DEVBASE_CONFIG_DIR (global)
# Modifies: Exports multiple DEVBASE_* environment variables
# Returns: 0 on success, 1 if preferences file not found
# Side-effects: Reads preferences.yaml, exports variables, prints summary
load_saved_preferences() {
  local prefs_file="${DEVBASE_CONFIG_DIR}/preferences.yaml"

  if [[ ! -f "$prefs_file" ]]; then
    return 1
  fi

  # yq is installed via mise, should be available during updates
  if ! command -v yq &>/dev/null; then
    show_progress warning "yq not found, cannot load preferences"
    return 1
  fi

  printf "\n"
  printf "%bLoading saved preferences from previous installation...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"

  # Parse YAML preferences file using yq
  # Note: yq returns 'null' for missing keys, we convert to empty string
  _yq_read() {
    local val
    val=$(yq "$1" "$2")
    [[ "$val" == "null" ]] && echo "" || echo "$val"
  }

  DEVBASE_THEME=$(_yq_read '.theme' "$prefs_file")
  DEVBASE_FONT=$(_yq_read '.font' "$prefs_file")
  DEVBASE_GIT_AUTHOR=$(_yq_read '.git.author' "$prefs_file")
  DEVBASE_GIT_EMAIL=$(_yq_read '.git.email' "$prefs_file")
  DEVBASE_SSH_KEY_NAME=$(_yq_read '.ssh.key_name' "$prefs_file")
  EDITOR=$(_yq_read '.editor.default' "$prefs_file")
  VISUAL="$EDITOR"
  DEVBASE_VSCODE_INSTALL=$(_yq_read '.vscode.install' "$prefs_file")
  DEVBASE_VSCODE_EXTENSIONS=$(_yq_read '.vscode.extensions' "$prefs_file")
  DEVBASE_VSCODE_NEOVIM=$(_yq_read '.vscode.neovim_extension' "$prefs_file")
  DEVBASE_INSTALL_LAZYVIM=$(_yq_read '.ide.lazyvim' "$prefs_file")
  DEVBASE_INSTALL_INTELLIJ=$(_yq_read '.ide.intellij' "$prefs_file")
  DEVBASE_INSTALL_JMC=$(_yq_read '.ide.jmc' "$prefs_file")
  DEVBASE_ZELLIJ_AUTOSTART=$(_yq_read '.tools.zellij_autostart' "$prefs_file")
  DEVBASE_ENABLE_GIT_HOOKS=$(_yq_read '.tools.git_hooks' "$prefs_file")

  # Load selected packs (array to space-separated string)
  DEVBASE_SELECTED_PACKS=$(yq -r '.packs // [] | .[]' "$prefs_file" | tr '\n' ' ' | sed 's/ $//')
  # Default to all packs if not set in preferences
  if [[ -z "$DEVBASE_SELECTED_PACKS" ]]; then
    DEVBASE_SELECTED_PACKS="java node python go ruby rust vscode-editor"
  fi

  export DEVBASE_THEME DEVBASE_FONT DEVBASE_GIT_AUTHOR DEVBASE_GIT_EMAIL DEVBASE_SSH_KEY_NAME
  export EDITOR VISUAL DEVBASE_VSCODE_INSTALL DEVBASE_VSCODE_EXTENSIONS DEVBASE_VSCODE_NEOVIM
  export DEVBASE_INSTALL_LAZYVIM DEVBASE_INSTALL_INTELLIJ DEVBASE_INSTALL_JMC
  export DEVBASE_ZELLIJ_AUTOSTART DEVBASE_ENABLE_GIT_HOOKS DEVBASE_SELECTED_PACKS

  # For updates, skip SSH key generation - keep existing key
  export DEVBASE_SSH_KEY_ACTION="skip"

  printf "  Theme: %s\n" "$DEVBASE_THEME"
  printf "  Git: %s <%s>\n" "$DEVBASE_GIT_AUTHOR" "$DEVBASE_GIT_EMAIL"
  printf "  Editor: %s\n" "$EDITOR"
  printf "  Packs: %s\n" "$DEVBASE_SELECTED_PACKS"

  show_progress success "Preferences loaded from ${prefs_file/#$HOME/~}"

  return 0
}

# Brief: Prompt user for git author name with validation
# Params: None
# Uses: print_prompt, show_progress, DEVBASE_COLORS (functions/globals)
# Modifies: DEVBASE_GIT_AUTHOR (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads from stdin, prints prompts/validation errors, validates name format (allows Unicode letters)
get_git_author_name() {
  local name_pattern='^[[:alpha:]]+[[:space:]]+[[:alpha:]]+$'
  local default_name
  default_name=$(git config --global user.name 2>/dev/null)

  if [[ ! "$default_name" =~ $name_pattern ]]; then
    default_name=""
  fi

  local git_name=""
  while true; do
    if [[ -n "$default_name" ]]; then
      print_prompt "Git author name (firstname lastname)" "$default_name"
    else
      printf "  %bGit author name (firstname lastname): %b" "${DEVBASE_COLORS[LIGHTYELLOW]}" "${DEVBASE_COLORS[NC]}"
    fi

    read -r git_name

    if [[ -z "$git_name" ]] && [[ -n "$default_name" ]]; then
      git_name="$default_name"
    fi

    if [[ "$git_name" =~ $name_pattern ]]; then
      export DEVBASE_GIT_AUTHOR="$git_name"
      break
    else
      show_progress validation "Please enter firstname and lastname (use letters only)"
    fi
  done
}

# Brief: Generate default email from author name
# Params: $1 - author name, $2 - email domain
# Returns: Echoes generated email to stdout
_generate_default_email_from_name() {
  local author_name="$1"
  local email_domain="$2"

  if [[ -n "$email_domain" ]] && [[ "$email_domain" != "@" ]]; then
    local email_prefix
    email_prefix=$(echo "$author_name" |
      iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null |
      sed 's/ /./g' |
      tr '[:upper:]' '[:lower:]' |
      tr -cd 'a-z.')
    echo "${email_prefix}${email_domain}"
  fi
}

# Brief: Prompt user for git email and read into variable
# Params: $1 - variable name to set, $2 - default email, $3 - email domain
# Returns: 0 always
# Side-effects: Sets the named variable to the email entered
_prompt_for_git_email() {
  local -n result_var=$1
  local default_email="$2"
  local email_domain="$3"
  local email_input=""

  if [[ -n "$default_email" ]]; then
    print_prompt "Git email" "$default_email"
  else
    if [[ -n "$email_domain" ]] && [[ "$email_domain" != "@" ]]; then
      printf "  %bGit email (e.g., firstname.lastname%s): %b" "${DEVBASE_COLORS[LIGHTYELLOW]}" "$email_domain" "${DEVBASE_COLORS[NC]}"
    else
      printf "  %bGit email: %b" "${DEVBASE_COLORS[LIGHTYELLOW]}" "${DEVBASE_COLORS[NC]}"
    fi
  fi

  read -r email_input

  if [[ -z "$email_input" ]] && [[ -n "$default_email" ]]; then
    result_var="$default_email"
  else
    result_var="$email_input"
  fi
}

# Brief: Append domain to email if missing (modifies variable in place)
# Params: $1 - variable name containing email, $2 - email domain
# Returns: 0 always
# Side-effects: Modifies the named variable to append domain if needed
_append_domain_if_needed() {
  local -n email_var=$1
  local email_domain="$2"

  if [[ -n "$email_domain" ]] && [[ "$email_domain" != "@" ]]; then
    if [[ ! "$email_var" =~ @ ]]; then
      email_var="${email_var}${email_domain}"
    fi
  fi
}

# Brief: Prompt user for git email with validation and domain handling
# Params: None
# Uses: print_prompt, show_progress, DEVBASE_GIT_AUTHOR, DEVBASE_EMAIL_DOMAIN, DEVBASE_COLORS, USER, hostname (globals)
# Modifies: DEVBASE_GIT_EMAIL (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads from stdin, prints prompts/validation, auto-generates email from name if domain provided
get_git_email() {
  local email_pattern='^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  local default_email
  default_email=$(git config --global user.email 2>/dev/null || echo "$USER@$(hostname)")

  if [[ ! "$default_email" =~ $email_pattern ]]; then
    default_email=$(_generate_default_email_from_name "${DEVBASE_GIT_AUTHOR}" "${DEVBASE_EMAIL_DOMAIN}")
  fi

  local git_email=""
  while true; do
    _prompt_for_git_email git_email "$default_email" "${DEVBASE_EMAIL_DOMAIN}"
    _append_domain_if_needed git_email "${DEVBASE_EMAIL_DOMAIN}"

    if [[ "$git_email" =~ $email_pattern ]]; then
      export DEVBASE_GIT_EMAIL="$git_email"
      break
    else
      show_progress validation "Please use format: firstname.lastname@domain.com"
    fi
  done
}

# Brief: Collect all git configuration from user
# Params: None
# Uses: print_section, get_git_author_name, get_git_email, DEVBASE_COLORS (functions/globals)
# Modifies: DEVBASE_GIT_AUTHOR, DEVBASE_GIT_EMAIL (exported)
# Returns: 0 always (implicit)
# Side-effects: Prints section header, calls other collection functions
collect_git_configuration() {
  printf "\n"
  print_section "Git Configuration" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"

  get_git_author_name
  get_git_email
}

# Brief: Prompt user to select color theme
# Params: None
# Uses: print_section, print_prompt, DEVBASE_COLORS (functions/globals)
# Modifies: DEVBASE_THEME (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads from stdin, prints theme menu, prints selected theme
collect_theme_preference() {
  printf "\n"
  print_section "Theme Selection" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"
  printf "  %bYou can change themes anytime after install with: devbase-theme <name>%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "\n"
  printf "  %bDark themes:%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "    1) everforest-dark   (default)  - Soft, warm, easy on eyes\n"
  printf "    2) catppuccin-mocha              - Pastel, cozy, modern\n"
  printf "    3) tokyonight-night              - Vibrant, neon-inspired\n"
  printf "    4) gruvbox-dark                  - Retro, warm, high contrast\n"
  printf "    5) nord                          - Arctic, cool, elegant\n"
  printf "    6) dracula                       - Purple, popular, vivid\n"
  printf "    7) solarized-dark                - Classic, precision colors\n"
  printf "\n"
  printf "  %bLight themes:%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "    8) everforest-light              - Soft, warm, comfortable\n"
  printf "    9) catppuccin-latte              - Pastel, cozy, gentle\n"
  printf "   10) tokyonight-day                - Clean, bright, modern\n"
  printf "   11) gruvbox-light                 - Retro, warm, readable\n"
  printf "   12) solarized-light               - Classic, precision colors\n"
  printf "\n"
  print_prompt "Choose theme [1-12 or name]" "1"
  read -r theme_choice
  case "${theme_choice,,}" in
  1 | everforest-dark | dark) export DEVBASE_THEME="everforest-dark" ;;
  2 | catppuccin-mocha | mocha) export DEVBASE_THEME="catppuccin-mocha" ;;
  3 | tokyonight-night | tokyonight) export DEVBASE_THEME="tokyonight-night" ;;
  4 | gruvbox-dark | gruvbox) export DEVBASE_THEME="gruvbox-dark" ;;
  5 | nord) export DEVBASE_THEME="nord" ;;
  6 | dracula) export DEVBASE_THEME="dracula" ;;
  7 | solarized-dark) export DEVBASE_THEME="solarized-dark" ;;
  8 | everforest-light | light) export DEVBASE_THEME="everforest-light" ;;
  9 | catppuccin-latte | latte) export DEVBASE_THEME="catppuccin-latte" ;;
  10 | tokyonight-day | day) export DEVBASE_THEME="tokyonight-day" ;;
  11 | gruvbox-light) export DEVBASE_THEME="gruvbox-light" ;;
  12 | solarized-light) export DEVBASE_THEME="solarized-light" ;;
  *) export DEVBASE_THEME="everforest-dark" ;;
  esac
  printf "  %b✓%b Selected: %b%s%b\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "${DEVBASE_COLORS[BOLD_GREEN]}" "${DEVBASE_THEME}" "${DEVBASE_COLORS[NC]}"
}

# Brief: Prompt user to select terminal font (skipped on WSL)
# Params: None
# Uses: print_section, print_prompt, _DEVBASE_ENV, DEVBASE_COLORS (globals)
# Modifies: DEVBASE_FONT (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads from stdin, prints font menu, prints selected font; skips on WSL
collect_font_preference() {
  # Skip font selection on WSL - fonts are managed by Windows Terminal
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    export DEVBASE_FONT=""
    return 0
  fi

  printf "\n"
  print_section "Font Selection" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"
  printf "  Choose a Nerd Font for your terminal and editors:\n"
  printf "\n"
  printf "    1) jetbrains-mono             - Clear, excellent readability\n"
  printf "    2) firacode                   - Popular, extensive ligatures\n"
  printf "    3) cascadia-code              - Microsoft, Powerline glyphs\n"
  printf "    4) monaspace       (default)  - Superfamily, multiple styles\n"
  printf "\n"
  printf "  %bAll fonts work in terminals, VSCode, and IntelliJ%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "\n"
  print_prompt "Choose font [1-4 or name]" "4"
  read -r font_choice
  case "${font_choice,,}" in
  1 | jetbrains-mono | jetbrains) export DEVBASE_FONT="jetbrains-mono" ;;
  2 | firacode | fira) export DEVBASE_FONT="firacode" ;;
  3 | cascadia-code | cascadia) export DEVBASE_FONT="cascadia-code" ;;
  4 | monaspace) export DEVBASE_FONT="monaspace" ;;
  *) export DEVBASE_FONT="monaspace" ;;
  esac
  printf "  %b✓%b Selected: %b%s%b\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "${DEVBASE_COLORS[BOLD_GREEN]}" "${DEVBASE_FONT}" "${DEVBASE_COLORS[NC]}"
}

# Brief: Prompt for SSH key passphrase with confirmation
# Params: None
# Uses: print_prompt, show_progress, DEVBASE_COLORS (globals)
# Modifies: DEVBASE_SSH_PASSPHRASE (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads password from stdin (hidden), validates min 12 chars per NIST, requires confirmation
prompt_for_ssh_passphrase() {
  local ssh_pass=""
  while true; do
    print_prompt "SSH key passphrase (min 12 chars)" ""
    read -s -r ssh_pass
    printf "\n"

    if [[ ${#ssh_pass} -lt 12 ]]; then
      show_progress validation "Passphrase must be at least 12 characters (NIST recommendation)"
      continue
    fi

    print_prompt "Confirm passphrase" ""
    read -s -r ssh_pass2
    printf "\n"
    if [[ "$ssh_pass" != "$ssh_pass2" ]]; then
      show_progress validation "Passphrases don't match - try again"
      continue
    fi
    printf "  %b✓%b Passphrase set\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    break
  done
  export DEVBASE_SSH_PASSPHRASE="${ssh_pass}"
}

# Brief: Handle existing SSH key scenario (keep or regenerate)
# Params: $1 - ssh_key_path
# Uses: ask_yes_no, show_progress, prompt_for_ssh_passphrase, DEVBASE_COLORS (functions/globals)
# Modifies: DEVBASE_SSH_KEY_ACTION (exported)
# Returns: 0 always (implicit)
# Side-effects: Prompts user, prints decision
handle_existing_ssh_key() {
  local ssh_key_path="$1"

  validate_not_empty "$ssh_key_path" "SSH key path" || return 1

  printf "  %b✓%b DevBase SSH key exists: %s\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "$ssh_key_path"
  if ask_yes_no "Generate new SSH key? (overwrite) (y/N)" "N"; then
    export DEVBASE_SSH_KEY_ACTION="new"
    show_progress info "Will overwrite existing DevBase SSH key"
    prompt_for_ssh_passphrase
  else
    export DEVBASE_SSH_KEY_ACTION="keep"
    printf "  %b✓%b Keeping existing DevBase SSH key\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Handle missing SSH key scenario (generate or skip)
# Params: None
# Uses: show_progress, ask_yes_no, prompt_for_ssh_passphrase (functions)
# Modifies: DEVBASE_SSH_KEY_ACTION (exported)
# Returns: 0 always (implicit)
# Side-effects: Prompts user, prints decision
handle_new_ssh_key() {
  show_progress info "No DevBase SSH key found"
  if ask_yes_no "Generate SSH key? (Y/n)" "Y"; then
    export DEVBASE_SSH_KEY_ACTION="new"
    prompt_for_ssh_passphrase
  else
    export DEVBASE_SSH_KEY_ACTION="skip"
    show_progress info "Skipping SSH key generation"
  fi
}

# Brief: Collect SSH key configuration from user
# Params: None
# Uses: print_section, handle_existing_ssh_key, handle_new_ssh_key, HOME, DEVBASE_COLORS (globals)
# Modifies: DEVBASE_SSH_KEY_ACTION (exported via handle_* functions)
# Returns: 0 always (implicit)
# Side-effects: Prints section header, checks for existing key file
collect_ssh_configuration() {
  validate_var_set "HOME" || return 1

  printf "\n"
  print_section "SSH Key Setup" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"
  printf "  %bSSH keys are used for secure authentication with Git and remote servers.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  local ssh_key_path="$HOME/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"

  if [[ -f "$ssh_key_path" ]]; then
    handle_existing_ssh_key "$ssh_key_path"
  else
    handle_new_ssh_key
  fi
}

# Brief: Collect editor and IDE installation preferences
# Params: None
# Uses: print_section, ask_yes_no, DEVBASE_COLORS (functions/globals)
# Modifies: DEVBASE_VSCODE_INSTALL, DEVBASE_VSCODE_EXTENSIONS, DEVBASE_VSCODE_NEOVIM, DEVBASE_INSTALL_LAZYVIM, DEVBASE_INSTALL_INTELLIJ (exported)
# Returns: 0 always (implicit)
# Side-effects: Prints section, prompts user multiple times, prints decisions
# Brief: Prompt for VS Code installation and extensions
# Returns: 0 always
_prompt_vscode_preferences() {
  printf "\n"

  if is_wsl; then
    printf "  %bVS Code: On WSL, VS Code runs from Windows and connects via Remote-WSL extension.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    if ask_yes_no "Configure VS Code Remote-WSL and extensions? (Y/n)" "Y"; then
      export DEVBASE_VSCODE_INSTALL="true"
      printf "  %b✓%b VS Code Remote-WSL will be configured\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    else
      export DEVBASE_VSCODE_INSTALL="false"
      export DEVBASE_VSCODE_EXTENSIONS="false"
      export DEVBASE_VSCODE_NEOVIM="false"
      printf "  %b✓%b VS Code configuration skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
      return 0
    fi
  else
    printf "  %bVS Code: Popular extensible code editor with rich ecosystem.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    if ask_yes_no "Install VS Code? (Y/n)" "Y"; then
      export DEVBASE_VSCODE_INSTALL="true"
      printf "  %b✓%b VS Code will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    else
      export DEVBASE_VSCODE_INSTALL="false"
      export DEVBASE_VSCODE_EXTENSIONS="false"
      export DEVBASE_VSCODE_NEOVIM="false"
      printf "  %b✓%b VS Code installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
      return 0
    fi
  fi

  printf "  %bInstall recommended VS Code extensions (includes language support, linters, formatters)?%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install VS Code extensions? (Y/n)" "Y"; then
    export DEVBASE_VSCODE_EXTENSIONS="true"
    printf "  %b✓%b VS Code extensions will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"

    printf "  %bThe Neovim extension enables Vim keybindings and commands in VS Code.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    if ask_yes_no "Include VS Code Neovim extension? (Y/n)" "Y"; then
      export DEVBASE_VSCODE_NEOVIM="true"
      printf "  %b✓%b Neovim extension will be included\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    else
      export DEVBASE_VSCODE_NEOVIM="false"
      printf "  %b✓%b Neovim extension will be skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    fi
  else
    export DEVBASE_VSCODE_EXTENSIONS="false"
    export DEVBASE_VSCODE_NEOVIM="false"
    printf "  %b✓%b VS Code extensions will be skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Prompt for LazyVim installation
# Returns: 0 always
_prompt_lazyvim_preferences() {
  printf "\n"
  printf "  %bLazyVim is a Neovim IDE configuration with LSP, treesitter, and modern plugins.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install LazyVim for NeoVim? (Y/n)" "Y"; then
    export DEVBASE_INSTALL_LAZYVIM="true"
    printf "  %b✓%b LazyVim will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_LAZYVIM="false"
    printf "  %b✓%b LazyVim installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Prompt for IntelliJ IDEA installation
# Returns: 0 always
_prompt_intellij_preferences() {
  printf "\n"
  printf "  %bIntelliJ IDEA Ultimate: Full-featured Java/Kotlin IDE with advanced tools (~1GB).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install IntelliJ IDEA? (y/N)" "N"; then
    export DEVBASE_INSTALL_INTELLIJ="true"
    printf "  %b✓%b IntelliJ IDEA will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_INTELLIJ="false"
    printf "  %b✓%b IntelliJ IDEA installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

collect_editor_preferences() {
  printf "\n"
  print_section "Editor & IDE Preferences" "${DEVBASE_COLORS[BOLD_CYAN]}"

  _prompt_vscode_preferences
  _prompt_lazyvim_preferences
  _prompt_intellij_preferences
}

# Brief: Prompt for shell key bindings (Vim vs Emacs)
# Returns: 0 always
_prompt_editor_bindings() {
  printf "\n"
  printf "  %bVim bindings: hjkl navigation, modes (normal/insert). Emacs: arrow keys, Ctrl shortcuts.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Use Vim key bindings in shell? (Y/n)" "Y"; then
    export EDITOR="nvim"
    export VISUAL="nvim"
    printf "  %b✓%b Vim key bindings enabled for shell\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    printf "  %b✓%b Default editor: nvim\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export EDITOR="nano"
    export VISUAL="nano"
    printf "  %b✓%b Emacs key bindings for shell\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    printf "  %b✓%b Default editor: nano\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Prompt for JMC installation
# Returns: 0 always
_prompt_jmc_installation() {
  printf "\n"
  printf "  %bJDK Mission Control (JMC) is Oracle's profiling/diagnostics tool for Java (~1GB).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install JMC? (y/N)" "N"; then
    export DEVBASE_INSTALL_JMC="true"
    printf "  %b✓%b JMC will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_JMC="false"
    printf "  %b✓%b JMC installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Prompt for Zellij auto-start preference
# Returns: 0 always
_prompt_zellij_autostart() {
  printf "\n"
  printf "  %bZellij: Modern terminal workspace with tabs, panes, and session management.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Enable Zellij auto-start when opening terminal? (Y/n)" "Y"; then
    export DEVBASE_ZELLIJ_AUTOSTART="true"
    printf "  %b✓%b Zellij auto-start enabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_ZELLIJ_AUTOSTART="false"
    printf "  %b✓%b Zellij auto-start disabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Prompt for global git hooks enablement
# Returns: 0 always
_prompt_git_hooks() {
  printf "\n"
  printf "  %bGlobal git hooks: Automatic pre-commit checks (linting, formatting, secret detection).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "  %bWARNING: Existing hooks in ~/.config/git/git-hooks/ will be backed up.%b\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Enable global git hooks? (Y/n)" "Y"; then
    export DEVBASE_ENABLE_GIT_HOOKS="true"
    printf "  %b✓%b Git hooks will be enabled globally for all repos\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_ENABLE_GIT_HOOKS="false"
    printf "  %b✓%b Git hooks disabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Collect tool and shell preference settings
# Params: None
# Uses: print_section, ask_yes_no, DEVBASE_COLORS (functions/globals)
# Modifies: EDITOR, VISUAL, DEVBASE_INSTALL_JMC, DEVBASE_ZELLIJ_AUTOSTART, DEVBASE_ENABLE_GIT_HOOKS (exported)
# Returns: 0 always (implicit)
# Side-effects: Prints section, prompts user multiple times, prints decisions
collect_tool_preferences() {
  printf "\n"
  print_section "Tool Preferences" "${DEVBASE_COLORS[BOLD_CYAN]}"

  _prompt_editor_bindings
  _prompt_jmc_installation
  _prompt_zellij_autostart
  _prompt_git_hooks
}

# Brief: Prompt user to select language packs
# Modifies: DEVBASE_SELECTED_PACKS (exported, space-separated list)
# Returns: 0 always
collect_pack_preferences() {
  # Source parser for get_available_packs if not already loaded
  if ! declare -f get_available_packs &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  printf "\n"
  print_section "Language Packs" "${DEVBASE_COLORS[BOLD_CYAN]}"

  printf "  %bSelect which language packs to install (all selected by default):%b\n\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"

  # Get available packs
  local packs=()
  local descriptions=()
  while IFS='|' read -r pack desc; do
    packs+=("$pack")
    descriptions+=("$desc")
  done < <(get_available_packs)

  # Use existing selection or default to all
  local current_selection=" ${DEVBASE_SELECTED_PACKS:-${packs[*]}} "

  # Helper to check if pack is selected
  _is_selected() {
    [[ "$current_selection" == *" $1 "* ]]
  }

  # Display current selection state
  local i=0
  local all_selected=true
  for pack in "${packs[@]}"; do
    if _is_selected "$pack"; then
      printf "  [x] %-15s - %s\n" "$pack" "${descriptions[$i]}"
    else
      printf "  [ ] %-15s - %s\n" "$pack" "${descriptions[$i]}"
      all_selected=false
    fi
    ((i++))
  done

  printf "\n"

  # Determine if this is a fresh install (no existing selection) or update
  local is_fresh_install=false
  [[ -z "${DEVBASE_SELECTED_PACKS:-}" ]] && is_fresh_install=true

  # Helper to display pack contents
  _show_pack_details() {
    local pack="$1"
    local desc="$2"
    printf "\n  %b%s%b: %s\n" "${DEVBASE_COLORS[BOLD]}" "$pack" "${DEVBASE_COLORS[NC]}" "$desc"
    printf "  %bIncludes:%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    local item
    while IFS= read -r item; do
      [[ -n "$item" ]] && printf "    %b- %s%b\n" "${DEVBASE_COLORS[DIM]}" "$item" "${DEVBASE_COLORS[NC]}"
    done < <(get_pack_contents "$pack")
  }

  if [[ "$is_fresh_install" == "true" ]]; then
    # Fresh install: ask if user wants all packs or to select individually
    if ask_yes_no "Install all language packs? (Y/n)" "Y"; then
      DEVBASE_SELECTED_PACKS="${packs[*]}"
      printf "  %b✓%b All packs selected\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    else
      # Let user select individually, showing pack contents
      local selected=()
      for i in "${!packs[@]}"; do
        local pack="${packs[$i]}"
        local desc="${descriptions[$i]}"
        _show_pack_details "$pack" "$desc"
        if ask_yes_no "  Install ${pack}? (Y/n)" "Y"; then
          selected+=("$pack")
        fi
      done
      DEVBASE_SELECTED_PACKS="${selected[*]}"
      printf "\n  %b✓%b Selected: %s\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "$DEVBASE_SELECTED_PACKS"
    fi
  else
    # Update: ask if user wants to keep current selection or change
    if ask_yes_no "Keep current selection? (Y/n)" "Y"; then
      # Keep current - DEVBASE_SELECTED_PACKS already set
      printf "  %b✓%b Keeping current selection\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    else
      # Let user select individually, showing pack contents
      local selected=()
      for i in "${!packs[@]}"; do
        local pack="${packs[$i]}"
        local desc="${descriptions[$i]}"
        local pack_default="Y"
        _is_selected "$pack" || pack_default="N"
        _show_pack_details "$pack" "$desc"
        if ask_yes_no "  Install ${pack}?" "$pack_default"; then
          selected+=("$pack")
        fi
      done
      DEVBASE_SELECTED_PACKS="${selected[*]}"
      printf "\n  %b✓%b Selected: %s\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "$DEVBASE_SELECTED_PACKS"
    fi
  fi

  export DEVBASE_SELECTED_PACKS
}

collect_user_configuration() {
  # Non-interactive mode: load saved prefs or use defaults, never prompt
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    setup_non_interactive_mode
    return 0
  fi

  # Interactive mode: load saved preferences as defaults (if they exist)
  # Then prompt user for all preferences, allowing them to change or keep defaults
  load_saved_preferences || true

  printf "\n"
  printf "%bEntering setup questions phase...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"

  collect_git_configuration
  collect_theme_preference
  collect_font_preference
  collect_ssh_configuration
  collect_editor_preferences
  collect_tool_preferences
  collect_pack_preferences

  write_user_preferences

  return 0
}

# Brief: Write collected preferences to YAML file
# Params: None
# Uses: DEVBASE_CONFIG_DIR and all DEVBASE_* preference variables (globals)
# Returns: 0 always (implicit)
# Side-effects: Creates config dir, writes preferences.yaml file, prints success message
write_user_preferences() {
  local prefs_file="${DEVBASE_CONFIG_DIR}/preferences.yaml"

  mkdir -p "${DEVBASE_CONFIG_DIR}"

  cat >"$prefs_file" <<EOF
# DevBase User Preferences
# Generated during installation: $(date)
# This file stores your installation choices for reference by scripts and tools

theme: ${DEVBASE_THEME}
font: ${DEVBASE_FONT}

git:
  author: ${DEVBASE_GIT_AUTHOR}
  email: ${DEVBASE_GIT_EMAIL}

ssh:
  key_action: ${DEVBASE_SSH_KEY_ACTION}
  key_name: ${DEVBASE_SSH_KEY_NAME}

editor:
  default: ${EDITOR}
  shell_bindings: $([ "${EDITOR}" == "nvim" ] && echo "vim" || echo "emacs")

vscode:
  install: ${DEVBASE_VSCODE_INSTALL}
  extensions: ${DEVBASE_VSCODE_EXTENSIONS}
  neovim_extension: ${DEVBASE_VSCODE_NEOVIM}

ide:
  lazyvim: ${DEVBASE_INSTALL_LAZYVIM}
  intellij: ${DEVBASE_INSTALL_INTELLIJ}
  jmc: ${DEVBASE_INSTALL_JMC}

tools:
  zellij_autostart: ${DEVBASE_ZELLIJ_AUTOSTART}
  git_hooks: ${DEVBASE_ENABLE_GIT_HOOKS}

packs: [${DEVBASE_SELECTED_PACKS:+${DEVBASE_SELECTED_PACKS// /, }}]
EOF

  show_progress success "User preferences saved to ${prefs_file/#$HOME/~}"
}
