#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
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

  if [[ -z "${SSH_KEY_PASSPHRASE:-}" ]]; then
    SSH_KEY_PASSPHRASE=$(generate_ssh_passphrase)
    export SSH_KEY_PASSPHRASE
    export GENERATED_SSH_PASSPHRASE="true"
    mkdir -p "${DEVBASE_CONFIG_DIR}"
    echo "$SSH_KEY_PASSPHRASE" >"${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
    chmod 600 "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
  fi

  export GIT_NAME="${GIT_NAME:-DevBase User}"
  export GIT_EMAIL="${GIT_EMAIL:-$USER@$(hostname)}"
  export EDITOR_CHOICE="${EDITOR_CHOICE:-nvim}"
  export DEVBASE_THEME="${DEVBASE_THEME:-everforest-dark}"
  export DEVBASE_ENV_NAME="${DEVBASE_ENV_NAME:-default}"
  export DEVBASE_INSTALL_DEVTOOLS="${DEVBASE_INSTALL_DEVTOOLS:-true}"
  export DEVBASE_INSTALL_LAZYVIM="${DEVBASE_INSTALL_LAZYVIM:-true}"
  export DEVBASE_VSCODE_INSTALL="${DEVBASE_VSCODE_INSTALL:-false}"
  export DEVBASE_SSH_KEY_ACTION="${DEVBASE_SSH_KEY_ACTION:-new}"

  printf "  Git Name: %s\n" "$GIT_NAME"
  printf "  Git Email: %s\n" "$GIT_EMAIL"
  printf "  Theme: %s\n" "$DEVBASE_THEME"
  printf "  Environment: %s\n" "$DEVBASE_ENV_NAME"
  if [[ "${GENERATED_SSH_PASSPHRASE:-false}" == "true" ]]; then
    printf "  SSH Key: Generated with secure passphrase\n"
  fi
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
    if [[ -n "${DEVBASE_EMAIL_DOMAIN}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
      # Convert name to email prefix: "John Doe" -> "john.doe"
      # Remove accents/diacritics using iconv (part of glibc, always available on Linux)
      local email_prefix
      email_prefix=$(echo "${DEVBASE_GIT_AUTHOR}" |
        iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null |
        sed 's/ /./' |
        tr '[:upper:]' '[:lower:]' |
        tr -cd 'a-z.')
      default_email="${email_prefix}${DEVBASE_EMAIL_DOMAIN}"
    else
      default_email=""
    fi
  fi

  local git_email=""
  while true; do
    if [[ -n "$default_email" ]]; then
      print_prompt "Git email" "$default_email"
    else
      if [[ -n "${DEVBASE_EMAIL_DOMAIN}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
        printf "  %bGit email (e.g., firstname.lastname%s): %b" "${DEVBASE_COLORS[LIGHTYELLOW]}" "${DEVBASE_EMAIL_DOMAIN}" "${DEVBASE_COLORS[NC]}"
      else
        printf "  %bGit email: %b" "${DEVBASE_COLORS[LIGHTYELLOW]}" "${DEVBASE_COLORS[NC]}"
      fi
    fi

    read -r git_email

    if [[ -z "$git_email" ]] && [[ -n "$default_email" ]]; then
      git_email="$default_email"
    fi

    if [[ -n "${DEVBASE_EMAIL_DOMAIN}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
      if [[ ! "$git_email" =~ @ ]]; then
        git_email="${git_email}${DEVBASE_EMAIL_DOMAIN}"
      fi
    fi

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
# Modifies: DEVBASE_GIT_DEFAULT_BRANCH (exported)
# Returns: 0 always (implicit)
# Side-effects: Prints section header, calls other collection functions
collect_git_configuration() {
  printf "\n"
  print_section "Git Configuration" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"

  get_git_author_name
  get_git_email

  export DEVBASE_GIT_DEFAULT_BRANCH="main"
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
  printf "  %bDark themes:%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "    1) everforest-dark   (default)\n"
  printf "    2) catppuccin-mocha\n"
  printf "    3) tokyonight-night\n"
  printf "    4) gruvbox-dark\n"
  printf "\n"
  printf "  %bLight themes:%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "    5) everforest-light\n"
  printf "    6) catppuccin-latte\n"
  printf "    7) tokyonight-day\n"
  printf "    8) gruvbox-light\n"
  printf "\n"
  print_prompt "Choose theme [1-8 or name]" "1"
  read -r theme_choice
  case "${theme_choice,,}" in
  1 | everforest-dark | dark) export DEVBASE_THEME="everforest-dark" ;;
  2 | catppuccin-mocha | mocha) export DEVBASE_THEME="catppuccin-mocha" ;;
  3 | tokyonight-night | tokyonight) export DEVBASE_THEME="tokyonight-night" ;;
  4 | gruvbox-dark | gruvbox) export DEVBASE_THEME="gruvbox-dark" ;;
  5 | everforest-light | light) export DEVBASE_THEME="everforest-light" ;;
  6 | catppuccin-latte | latte) export DEVBASE_THEME="catppuccin-latte" ;;
  7 | tokyonight-day | day) export DEVBASE_THEME="tokyonight-day" ;;
  8 | gruvbox-light) export DEVBASE_THEME="gruvbox-light" ;;
  *) export DEVBASE_THEME="everforest-dark" ;;
  esac
  printf "  %b✓%b Selected: %b%s%b\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" "${DEVBASE_COLORS[BOLD_GREEN]}" "${DEVBASE_THEME}" "${DEVBASE_COLORS[NC]}"
}

# Brief: Prompt for SSH key passphrase with confirmation
# Params: None
# Uses: print_prompt, show_progress, DEVBASE_SSH_ALLOW_EMPTY_PW, DEVBASE_COLORS (globals)
# Modifies: DEVBASE_SSH_PASSPHRASE (exported)
# Returns: 0 always (implicit)
# Side-effects: Reads password from stdin (hidden), validates length, requires confirmation
prompt_for_ssh_passphrase() {
  local ssh_pass=""
  while true; do
    print_prompt "SSH key passphrase (min 6 chars)" ""
    read -s -r ssh_pass
    printf "\n"

    if [[ -z "$ssh_pass" ]]; then
      if [[ "${DEVBASE_SSH_ALLOW_EMPTY_PW:-false}" == "true" ]]; then
        show_progress info "No passphrase set (allowed by config)"
        break
      else
        show_progress validation "Passphrase must be at least 6 characters for security"
        continue
      fi
    elif [[ ${#ssh_pass} -lt 6 ]]; then
      show_progress validation "Too short - use at least 6 characters"
      continue
    fi

    if [[ -n "$ssh_pass" ]]; then
      print_prompt "Confirm passphrase" ""
      read -s -r ssh_pass2
      printf "\n"
      if [[ "$ssh_pass" != "$ssh_pass2" ]]; then
        show_progress validation "Passphrases don't match - try again"
        continue
      fi
      printf "  %b✓%b Passphrase set\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    fi
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
# Modifies: DEVBASE_SSH_KEY_PATH (exported)
# Returns: 0 always (implicit)
# Side-effects: Prints section header, checks for existing key file
collect_ssh_configuration() {
  validate_var_set "HOME" || return 1

  printf "\n"
  print_section "SSH Key Setup" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"
  printf "  %bSSH keys are used for secure authentication with Git and remote servers.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  local ssh_key_path="$HOME/.ssh/id_ecdsa_nistp521_devbase"
  export DEVBASE_SSH_KEY_PATH="$ssh_key_path"

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
collect_editor_preferences() {
  printf "\n"
  print_section "Editor & IDE Preferences" "${DEVBASE_COLORS[BOLD_CYAN]}"

  printf "\n"
  printf "  %bVS Code: Popular extensible code editor with rich ecosystem.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install VS Code? (Y/n)" "Y"; then
    export DEVBASE_VSCODE_INSTALL="true"
    printf "  %b✓%b VS Code will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"

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
  else
    export DEVBASE_VSCODE_INSTALL="false"
    export DEVBASE_VSCODE_EXTENSIONS="false"
    export DEVBASE_VSCODE_NEOVIM="false"
    printf "  %b✓%b VS Code installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi

  printf "\n"
  printf "  %bLazyVim is a Neovim IDE configuration with LSP, treesitter, and modern plugins.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install LazyVim for NeoVim? (Y/n)" "Y"; then
    export DEVBASE_INSTALL_LAZYVIM="true"
    printf "  %b✓%b LazyVim will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_LAZYVIM="false"
    printf "  %b✓%b LazyVim installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi

  printf "\n"
  printf "  %bIntelliJ IDEA Ultimate: Full-featured Java/Kotlin IDE with advanced tools (~1GB).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install IntelliJ IDEA? (y/N)" "N"; then
    export DEVBASE_INSTALL_INTELLIJ="yes"
    printf "  %b✓%b IntelliJ IDEA will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_INTELLIJ="no"
    printf "  %b✓%b IntelliJ IDEA installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
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

  printf "\n"
  printf "  %bJDK Mission Control (JMC) is Oracle's profiling/diagnostics tool for Java (~1GB).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Install JMC? (y/N)" "N"; then
    export DEVBASE_INSTALL_JMC="yes"
    printf "  %b✓%b JMC will be installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_INSTALL_JMC="no"
    printf "  %b✓%b JMC installation skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi

  printf "\n"
  printf "  %bZellij: Modern terminal workspace with tabs, panes, and session management.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Enable Zellij auto-start when opening terminal? (Y/n)" "Y"; then
    export DEVBASE_ZELLIJ_AUTOSTART="true"
    printf "  %b✓%b Zellij auto-start enabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_ZELLIJ_AUTOSTART="false"
    printf "  %b✓%b Zellij auto-start disabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi

  printf "\n"
  printf "  %bGlobal git hooks: Automatic pre-commit checks (linting, formatting, secret detection).%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "  %bWARNING: Existing hooks in ~/.config/git/git-hooks/ will be backed up.%b\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_COLORS[NC]}"
  if ask_yes_no "Enable global git hooks? (Y/n)" "Y"; then
    export DEVBASE_ENABLE_GIT_HOOKS="yes"
    printf "  %b✓%b Git hooks will be enabled globally for all repos\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  else
    export DEVBASE_ENABLE_GIT_HOOKS="no"
    printf "  %b✓%b Git hooks disabled\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
  fi
}

collect_user_configuration() {
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    setup_non_interactive_mode
    return 0
  fi

  printf "\n"
  printf "%bEntering setup questions phase...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"

  collect_git_configuration
  collect_theme_preference
  collect_ssh_configuration
  collect_editor_preferences
  collect_tool_preferences

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

theme: ${DEVBASE_THEME:-everforest-dark}

git:
  author: ${DEVBASE_GIT_AUTHOR:-}
  email: ${DEVBASE_GIT_EMAIL:-}

ssh:
  key_action: ${DEVBASE_SSH_KEY_ACTION:-keep}
  key_path: ${DEVBASE_SSH_KEY_PATH:-~/.ssh/id_ecdsa_nistp521_devbase}

editor:
  default: ${EDITOR:-nvim}
  shell_bindings: $([ "${EDITOR:-nvim}" == "nvim" ] && echo "vim" || echo "emacs")

vscode:
  install: ${DEVBASE_VSCODE_INSTALL:-true}
  extensions: ${DEVBASE_VSCODE_EXTENSIONS:-true}
  neovim_extension: ${DEVBASE_VSCODE_NEOVIM:-true}

ide:
  lazyvim: ${DEVBASE_INSTALL_LAZYVIM:-true}
  intellij: $([ "${DEVBASE_INSTALL_INTELLIJ:-no}" == "yes" ] && echo "true" || echo "false")
  jmc: $([ "${DEVBASE_INSTALL_JMC:-no}" == "yes" ] && echo "true" || echo "false")

tools:
  zellij_autostart: ${DEVBASE_ZELLIJ_AUTOSTART:-true}
  git_hooks: $([ "${DEVBASE_ENABLE_GIT_HOOKS:-yes}" == "yes" ] && echo "true" || echo "false")
EOF

  show_progress success "User preferences saved to ${prefs_file/#$HOME/~}"
}
