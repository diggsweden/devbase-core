#!/usr/bin/env bash

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

set -uo pipefail
trap 'printf "Error on line %d, command: %s\n" "$LINENO" "$BASH_COMMAND"' ERR

# Brief: Safely remove temporary directory with path validation
# Params: None
# Uses: _DEVBASE_TEMP (global)
# Returns: 0 always
# Side-effects: Removes _DEVBASE_TEMP directory if path matches expected pattern
cleanup_temp_directory() {
  if [[ -z "${_DEVBASE_TEMP:-}" ]]; then
    return 0
  fi

  if [[ ! -d "${_DEVBASE_TEMP}" ]]; then
    return 0
  fi

  local real_path
  real_path=$(realpath -m "${_DEVBASE_TEMP}" 2>/dev/null) || return 0

  if [[ "$real_path" =~ ^/tmp/devbase\.[A-Za-z0-9]+$ ]]; then
    rm -rf "$real_path" 2>/dev/null || true
  fi

  return 0
}

# Brief: Handle SIGINT/SIGTERM by cleaning up and exiting with code 130
# Params: None
# Uses: cleanup_temp_directory (function)
# Returns: exits with 130
# Side-effects: Cleans temp directory, prints cancellation message, exits
handle_interrupt() {
  cleanup_temp_directory
  printf "\n\nInstallation cancelled by user (Ctrl+C)\n" >&2
  exit 130
}

trap cleanup_temp_directory EXIT
trap handle_interrupt INT TERM

source "${DEVBASE_ROOT}/libs/collect-user-preferences.sh"
source "${DEVBASE_ROOT}/libs/process-templates.sh"
source "${DEVBASE_ROOT}/libs/install-apt.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-snap.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-mise.sh"
source "${DEVBASE_ROOT}/libs/install-custom.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-completions.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-shell.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-services.sh"
source "${DEVBASE_ROOT}/libs/setup-vscode.sh"

_VERSIONS_FILE=""
_DEVBASE_TEMP=$(mktemp -d /tmp/devbase.XXXXXX) || {
  echo "ERROR: Failed to create temp directory" >&2
  exit 1
}

readonly _DEVBASE_TEMP

# Rotate old backup if it exists (keep only one previous backup)
if [[ -d "${DEVBASE_BACKUP_DIR}" ]]; then
  if [[ -d "${DEVBASE_BACKUP_DIR}.old" ]]; then
    # Safety check: ensure path is within user home
    if [[ -n "${DEVBASE_BACKUP_DIR}" ]] && [[ "${DEVBASE_BACKUP_DIR}.old" =~ ^${HOME}/ ]] && [[ ! "${DEVBASE_BACKUP_DIR}.old" =~ \.\. ]]; then
      rm -rf "${DEVBASE_BACKUP_DIR}.old"
    else
      show_progress warning "Refusing to remove unsafe backup path: ${DEVBASE_BACKUP_DIR}.old"
    fi
  fi
  mv "${DEVBASE_BACKUP_DIR}" "${DEVBASE_BACKUP_DIR}.old"
fi

# Clean up old timestamped backups from previous version
for old_backup in "${HOME}"/.devbase_backup_*; do
  if [[ -d "$old_backup" ]]; then
    if [[ "$old_backup" =~ ^${HOME}/\.devbase_backup_[0-9]+$ ]]; then
      rm -rf "$old_backup"
    else
      show_progress warning "Skipping unexpected backup path: $old_backup"
    fi
  fi
done
if [[ -z "${DEVBASE_ROOT:-}" ]] || [[ -z "${DEVBASE_LIBS:-}" ]]; then
  echo "ERROR: Devbase environment not properly initialized" >&2
  exit 1
fi

# All required libraries are now sourced in setup.sh before this script
# This prevents duplicate sourcing and readonly variable conflicts

# Brief: Validate installation environment variables and critical tools
# Params: None
# Uses: validate_required_vars, check_critical_tools (functions from check-requirements.sh)
# Returns: 0 always (called functions exit on failure)
# Side-effects: Validates required environment and tools
validate_environment() {
  validate_required_vars
  check_critical_tools

  return 0
}

# Brief: Configure sudo to preserve proxy environment variables
# Params: None
# Uses: DEVBASE_FILES, DEVBASE_PROXY_URL, validate_var_set, show_progress (globals/functions)
# Returns: 0 always, 1 if validation fails
# Side-effects: Copies sudoers config file if proxy is configured
setup_sudo_and_system() {
  validate_var_set "DEVBASE_FILES" || return 1

  if [[ -n "${DEVBASE_PROXY_URL}" ]] && [[ -f "${DEVBASE_FILES}/sudo-keep-proxyenv/sudokeepenv" ]]; then
    show_progress info "Configuring sudo proxy preservation..."
    sudo cp "${DEVBASE_FILES}/sudo-keep-proxyenv/sudokeepenv" /etc/sudoers.d/
    sudo chmod 0440 /etc/sudoers.d/sudokeepenv

    if sudo visudo -c &>/dev/null; then
      show_progress success "Sudo proxy preservation configured"
    else
      show_progress warning "Could not validate sudoers proxy config - continuing anyway"
    fi
  fi

  return 0
}

# Brief: Validate devbase-core source repository structure
# Params: None
# Uses: validate_dir_exists, die (functions)
# Returns: 0 on success (dies on failure)
# Side-effects: Checks for required directories, exits if missing
validate_source_repository() {
  local required_dirs=("devbase_files" "dot" "environments" "libs")

  for dir in "${required_dirs[@]}"; do
    validate_dir_exists "$dir" "Required directory" || die "Directory missing: $dir (not running from devbase-core?)"
  done

  return 0
}

# Brief: Initialize installation file paths and validate temp directory
# Params: None
# Uses: DEVBASE_DOT, _DEVBASE_TEMP, validate_var_set (globals/functions)
# Modifies: _VERSIONS_FILE (global)
# Returns: 0 on success, 1 if validation fails
# Side-effects: Sets _VERSIONS_FILE path
setup_installation_paths() {
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "_DEVBASE_TEMP" || return 1

  _VERSIONS_FILE="${DEVBASE_DOT}/.config/devbase/versions.yaml"

  return 0
}

cleanup() {
  validate_var_set "DEVBASE_FILES" || return 1
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "XDG_CONFIG_HOME" || return 1
  validate_var_set "XDG_DATA_HOME" || return 1

  show_progress info "Cleaning up installation..."

  local files_cleaned=0

  local config_files=(
    "${DEVBASE_FILES}/unattended-upgrades-debian/50unattended-upgrades:/etc/apt/apt.conf.d/50unattended-upgrades"
    "${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua:${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua"
  )

  for mapping in "${config_files[@]}"; do
    IFS=':' read -r src dst <<<"$mapping"
    if [[ -f "$src" ]]; then
      [[ -d "$(dirname "$dst")" ]] && sudo cp "$src" "$dst"
    fi
  done

  # DEVBASE_BACKUP_DIR already created by ensure_user_dirs()

  if command -v podman >/dev/null 2>&1; then
    if [[ -d "${XDG_DATA_HOME}/containers/storage" ]]; then
      local podman_size
      podman_size=$(du -sm "${XDG_DATA_HOME}/containers/storage" 2>/dev/null | cut -f1)
      podman system reset --force || true
      files_cleaned=$((files_cleaned + ${podman_size:-0}))
    fi
  fi

  backup_if_exists "${XDG_CONFIG_HOME}/nvim/.git" "nvim-git-old"

  pkg_cleanup

  show_progress success "Cleanup complete"
  return 0
}

write_installation_summary() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  cat >"${DEVBASE_CONFIG_DIR}/install-summary.txt" <<EOF
DEVBASE INSTALLATION SUMMARY
============================
Installation Date: $(date)
Environment: ${_DEVBASE_ENV:-unknown}
Theme: ${DEVBASE_THEME:-everforest-dark}

INSTALLED TOOLS
===============
Development Languages:
  • Node.js: $(command -v node >/dev/null && node --version | sed 's/^v//' || echo "20.18.1")
  • Python: $(command -v python >/dev/null && python --version 2>&1 | cut -d' ' -f2 || echo "3.12")
  • Go: $(command -v go >/dev/null && go version | cut -d' ' -f3 | sed 's/go//' || echo "1.23.4")
  • Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "temurin-21")

Shell & Terminal:
  • Fish: $(fish --version 2>/dev/null | cut -d' ' -f3 || echo "3.7+")
  • Starship: $(starship --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "1.21.1")
  • Zellij: $(command -v zellij >/dev/null && zellij --version | cut -d' ' -f2 || echo "0.41.2")
  • Clipboard: ${ZELLIJ_COPY_COMMAND:-not detected}

Development Tools:
  • Neovim: $(nvim --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "0.10.3")
  • Lazygit: $(lazygit --version 2>/dev/null | grep -oP 'version=\K[^,]+' || echo "0.55.0")
  • Git: $(git --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)

Container Tools:
  • Podman: $(command -v podman &>/dev/null && echo "installed" || echo "not installed")
  • Buildah: $(command -v buildah &>/dev/null && echo "installed" || echo "not installed")

Optional Tools:
  • JMC: $(command -v jmc &>/dev/null && echo "installed" || echo "not installed (optional)")

CONFIGURATION
=============
Git Config:
  • Name: $(git config --global user.name 2>/dev/null || echo "not configured")
  • Email: $(git config --global user.email 2>/dev/null || echo "not configured")

SSH Key:
  • Key exists: $([ -f ~/.ssh/id_ecdsa_nistp521_devbase ] && echo "yes" || echo "no")

Proxy Settings:
  • Proxy: $(if [[ -n "${DEVBASE_PROXY_URL:-}" ]]; then echo "${DEVBASE_PROXY_URL}" | sed 's|://[^@]*@|://***:***@|'; else echo "not configured"; fi)
EOF

  return 0
}

show_completion_message() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  local box_width=70 # Wider to accommodate the summary path
  print_box_top "Installation Complete" "$box_width"
  print_box_line "Environment: ${_DEVBASE_ENV:-unknown}" "$box_width"
  print_box_line "Summary: ${DEVBASE_CONFIG_DIR}/install-summary.txt" "$box_width"
  print_box_line "Verify: ./verify/verify-install-check.sh (after new login)" "$box_width"

  if [[ "${GENERATED_SSH_PASSPHRASE:-false}" == "true" ]] && [[ -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" ]]; then
    local passphrase
    passphrase=$(cat "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" 2>/dev/null)
    if [[ -n "$passphrase" ]]; then
      print_box_line "" "$box_width"
      print_box_line "SSH Key Passphrase (save this!):" "$box_width"
      print_box_line "$passphrase" "$box_width"
      print_box_line "" "$box_width"
      print_box_line "To change: ssh-keygen -p -f ~/.ssh/id_ecdsa_nistp521_devbase" "$box_width"
    fi
    rm -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
  fi

  if [[ -z "${DEVBASE_CUSTOM_DIR:-}" ]]; then
    print_box_line "" "$box_width"
    print_box_line "Note: Using default configuration" "$box_width"
    print_box_line "For custom overlay (proxy, certs, hooks):" "$box_width"
    print_box_line "  1. Clone devbase-custom-config beside devbase-core" "$box_width"
    print_box_line "  2. Re-run setup.sh to apply custom settings" "$box_width"
  fi

  print_box_bottom "$box_width"
  return 0
}

handle_wsl_restart() {
  if [[ "${_DEVBASE_ENV:-}" == "wsl-ubuntu" ]]; then
    show_progress info "[WSL-specific] WSL must restart to apply all changes"
    printf "\n"
    printf "  %b%b%bPress ENTER to shutdown WSL now...%b" \
      "${DEVBASE_COLORS[BOLD_YELLOW]}" \
      "${DEVBASE_COLORS[BLINK_SLOW]}" \
      "${DEVBASE_COLORS[BOLD]}" \
      "${DEVBASE_COLORS[NC]}"
    read -r

    printf "\nShutting down WSL...\n"
    wsl.exe --shutdown
    exit 0 # Ensure script stops here
  fi
  return 0
}

# Brief: Install all development tools (APT, snap, mise, custom tools)
# Params: None
# Uses: install_apt_packages, install_snap_packages, install_mise_and_tools, install_fisher, install_lazyvim, install_jmc, install_oc_kubectl, install_vscode, install_dbeaver, install_keystore_explorer, install_intellij_idea, install_k3s, die, show_progress (functions)
# Returns: 0 always (critical failures call die)
# Side-effects: Installs all configured development tools
download_and_install_tools() {
  install_apt_packages || die "Failed to install APT packages"
  install_snap_packages || die "Failed to install snap packages"
  install_mise_and_tools || die "Failed to install mise and development tools"
  install_fisher || show_progress warning "Fisher/fzf.fish setup failed (continuing)"
  install_lazyvim || show_progress warning "LazyVim setup failed (continuing)"
  install_jmc || show_progress warning "JMC setup failed (continuing)"
  install_oc_kubectl || show_progress warning "oc/kubectl setup failed (continuing)"
  install_vscode || show_progress warning "VS Code setup failed (continuing)"
  install_dbeaver || show_progress warning "DBeaver setup failed (continuing)"
  install_keystore_explorer || show_progress warning "KeyStore Explorer setup failed (continuing)"
  install_intellij_idea || show_progress warning "IntelliJ IDEA setup failed (continuing)"
  install_k3s || show_progress warning "k3s setup failed (continuing)"

  return 0
}

# Brief: Apply user configurations (dotfiles, certificates, SSH, Git, VS Code)
# Params: None
# Uses: process_and_copy_dotfiles, install_certificates, configure_ssh, configure_git, configure_git_hooks, setup_vscode, DEVBASE_VSCODE_INSTALL, die, show_progress (functions/globals)
# Returns: 0 always (critical failures call die)
# Side-effects: Processes templates, installs certs, configures SSH/Git
apply_configurations() {

  process_and_copy_dotfiles || die "Failed to process dotfiles"
  install_certificates || die "Failed to install certificates"
  configure_ssh || die "Failed to configure SSH"
  configure_git || die "Failed to configure Git"
  configure_git_hooks || die "Failed to configure git hooks"

  # Setup VS Code extensions if VS Code is installed
  if [[ "${DEVBASE_VSCODE_INSTALL:-true}" == "true" ]]; then
    setup_vscode || show_progress warning "VSCode setup skipped or failed (continuing)"
  fi

  return 0
}

# Brief: Configure system services, shell, and Windows Terminal themes (WSL)
# Params: None
# Uses: configure_podman_service, configure_clamav_service, configure_ufw, configure_wayland_service, disable_kubernetes_services, set_system_limits, configure_fish_interactive, configure_completions, DEVBASE_LIBS, die, show_progress (functions/globals)
# Returns: 0 always (critical failures call die)
# Side-effects: Enables services, configures shell, installs WT themes on WSL
configure_system_and_shell() {
  configure_podman_service || die "Failed to configure podman service"
  configure_clamav_service || die "Failed to configure clamav service"
  configure_ufw || die "Failed to configure UFW firewall"
  configure_wayland_service || die "Failed to configure wayland service"
  disable_kubernetes_services || die "Failed to disable kubernetes services"
  set_system_limits || die "Failed to set system limits"

  configure_fish_interactive || die "Failed to setup fish for interactive use"
  configure_completions || die "Failed to configure shell completions"

  # Install all Windows Terminal themes if in WSL
  if uname -r | grep -qi microsoft; then
    show_progress info "Installing Windows Terminal themes..."
    # shellcheck disable=SC1091 # File exists at runtime
    if source "${DEVBASE_LIBS}/install-windows-terminal-themes.sh" && install_windows_terminal_themes 2>&1 | tee /dev/tty | grep -q "✓"; then
      show_progress success "Windows Terminal themes configured"
    else
      show_progress warning "Windows Terminal themes installation failed (continuing)"
    fi
  fi

  return 0
}

finalize_installation() {
  validate_var_set "DEVBASE_LIBS" || return 1
  validate_var_set "XDG_DATA_HOME" || return 1

  cleanup

  # Copy helper scripts to user data directory (directory already created by ensure_user_dirs())
  if [[ -f "${DEVBASE_LIBS}/install-windows-terminal-themes.sh" ]]; then
    cp "${DEVBASE_LIBS}/install-windows-terminal-themes.sh" "$XDG_DATA_HOME/devbase/libs/" 2>/dev/null || true
  fi

  return 0
}

display_configuration_summary() {
  validate_var_set "DEVBASE_GIT_AUTHOR" || return 1
  validate_var_set "DEVBASE_GIT_EMAIL" || return 1
  validate_var_set "DEVBASE_THEME" || return 1
  validate_var_set "DEVBASE_SSH_KEY_ACTION" || return 1
  validate_var_set "DEVBASE_SSH_KEY_PATH" || return 1

  printf "\n"
  print_box_top "Configuration Summary" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "Git Configuration:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • Author: ${DEVBASE_GIT_AUTHOR}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • Email: ${DEVBASE_GIT_EMAIL}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "Theme:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  case "${DEVBASE_THEME}" in
  everforest-dark)
    print_box_line "  • Everforest Dark" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  everforest-light)
    print_box_line "  • Everforest Light" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  catppuccin-mocha)
    print_box_line "  • Catppuccin Mocha" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  catppuccin-latte)
    print_box_line "  • Catppuccin Latte" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  tokyonight-night)
    print_box_line "  • Tokyo Night" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  tokyonight-day)
    print_box_line "  • Tokyo Night Day" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  gruvbox-dark)
    print_box_line "  • Gruvbox Dark" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  gruvbox-light)
    print_box_line "  • Gruvbox Light" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  *)
    print_box_line "  • ${DEVBASE_THEME}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    ;;
  esac
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "SSH Key:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${DEVBASE_SSH_KEY_ACTION}" == "new" ]]; then
    print_box_line "  • Action: Generate new key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Location: ${DEVBASE_SSH_KEY_PATH}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    if [[ -n "${DEVBASE_SSH_PASSPHRASE}" ]]; then
      print_box_line "  • Protection: With passphrase" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    else
      print_box_line "  • Protection: No passphrase" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    fi
  elif [[ "${DEVBASE_SSH_KEY_ACTION}" == "skip" ]]; then
    print_box_line "  • Action: No SSH key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Action: Keep existing key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Location: ${DEVBASE_SSH_KEY_PATH}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "Editor & Shell:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${EDITOR:-}" == "nvim" ]]; then
    print_box_line "  • Default editor: Neovim" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Shell bindings: Vim mode" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Default editor: Nano" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Shell bindings: Emacs mode" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  # Detect and show clipboard utility
  local clipboard_util
  clipboard_util=$(detect_clipboard_utility 2>/dev/null || echo "not detected")
  print_box_line "Clipboard:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • ${clipboard_util}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "IDE & Editor Extensions:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${DEVBASE_VSCODE_INSTALL:-true}" == "true" ]]; then
    print_box_line "  • VS Code: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    if [[ "${DEVBASE_VSCODE_EXTENSIONS:-true}" == "true" ]]; then
      print_box_line "    - Extensions: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
      if [[ "${DEVBASE_VSCODE_NEOVIM:-false}" == "true" ]]; then
        print_box_line "    - Neovim extension: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
      else
        print_box_line "    - Neovim extension: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
      fi
    else
      print_box_line "    - Extensions: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    fi
  else
    print_box_line "  • VS Code: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  if [[ "${DEVBASE_INSTALL_LAZYVIM:-true}" == "true" ]]; then
    print_box_line "  • LazyVim: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • LazyVim: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  if [[ "${DEVBASE_INSTALL_INTELLIJ:-no}" == "yes" ]]; then
    print_box_line "  • IntelliJ IDEA: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • IntelliJ IDEA: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  if [[ "${DEVBASE_INSTALL_JMC:-no}" == "yes" ]]; then
    print_box_line "  • JDK Mission Control: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • JDK Mission Control: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_line "Tools & Integrations:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${DEVBASE_ZELLIJ_AUTOSTART:-true}" == "true" ]]; then
    print_box_line "  • Zellij auto-start: Enabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Zellij auto-start: Disabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  if [[ "${DEVBASE_ENABLE_GIT_HOOKS:-yes}" == "yes" ]]; then
    print_box_line "  • Global git hooks: Enabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Global git hooks: Disabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  print_box_bottom 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  printf "\n"
  print_box_top "Installation Overview" 60 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_line "• Estimated time: 10-15 minutes" 60
  print_box_line "• Disk space required: ~6GB" 60
  print_box_line "• Internet connection required" 60
  print_box_line "• You may be prompted for sudo password" 60
  print_box_bottom 60 "${DEVBASE_COLORS[BOLD_CYAN]}"

  printf "\n"
  if ! ask_yes_no "Ready to install with these settings? (Y/n)" "Y"; then
    show_progress info "Installation cancelled"
    exit 0
  fi
}

# Brief: Prepare system by obtaining sudo access and ensuring user directories
# Params: None
# Uses: USER, show_progress, die, ensure_user_dirs, setup_sudo_and_system (globals/functions)
# Returns: 0 always (dies on failure)
# Side-effects: Prompts for sudo password (3 attempts), creates user directories
prepare_system() {
  # PHASE 1: System Preparation (first actual changes)
  if ! sudo -n true 2>/dev/null; then
    show_progress info "Sudo access required for system package installation"

    # Give user 3 attempts to enter correct sudo password
    local sudo_attempts=0
    local max_attempts=3

    # Temporarily disable exit on error for sudo handling
    set +e

    while [[ $sudo_attempts -lt $max_attempts ]]; do
      sudo_attempts=$((sudo_attempts + 1))

      if [[ $sudo_attempts -gt 1 ]]; then
        show_progress warning "Incorrect password. Attempt $sudo_attempts of $max_attempts"
        sudo -k 2>/dev/null
      fi

      local sudo_success=false

      # First try sudo normally to see if it can access a terminal
      if sudo -v 2>/dev/null; then
        sudo_success=true
      else
        # If sudo can't find a terminal, read password manually
        printf "  [sudo] password for %s: " "$USER"
        IFS= read -r -s sudo_password
        printf "\n"
        if [[ -n "$sudo_password" ]]; then
          if echo "$sudo_password" | sudo -S -v 2>/dev/null; then
            sudo_success=true
          fi
          unset sudo_password
        fi
      fi

      if [[ "$sudo_success" == "true" ]]; then
        show_progress success "Sudo access granted"
        break
      fi

      if [[ $sudo_attempts -eq $max_attempts ]]; then
        printf "\n"
        die "Failed to obtain sudo privileges after $max_attempts attempts"
      fi
    done
  else
    show_progress success "Sudo access already available"
  fi

  ensure_user_dirs

  setup_sudo_and_system
}

# Brief: Perform complete DevBase installation (tools, configs, services, hooks)
# Params: None
# Uses: DEVBASE_COLORS, DEVBASE_CUSTOM_HOOKS, download_and_install_tools, apply_configurations, configure_system_and_shell, finalize_installation, run_custom_hook, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Installs tools, applies configs, runs custom hooks
perform_installation() {
  printf "\n%bInstalling development tools...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  download_and_install_tools

  printf "\n%bApplying configurations...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  apply_configurations

  printf "\n%bConfiguring system services...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  configure_system_and_shell

  if [[ -n "${DEVBASE_CUSTOM_HOOKS}" ]] && [[ -d "${DEVBASE_CUSTOM_HOOKS}" ]]; then
    run_custom_hook "post-configuration" || show_progress warning "Post-configuration hook failed"
  fi

  printf "\n%bFinalizing installation...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  finalize_installation

  if [[ -n "${DEVBASE_CUSTOM_HOOKS}" ]] && [[ -d "${DEVBASE_CUSTOM_HOOKS}" ]]; then
    run_custom_hook "post-install" || show_progress warning "Post-install hook failed, continuing..."
  fi
}

# Brief: Main installation orchestration function
# Params: None
# Uses: DEVBASE_COLORS, validate_environment, validate_source_repository, setup_installation_paths, collect_user_configuration, display_configuration_summary, prepare_system, perform_installation, write_installation_summary, show_completion_message, handle_wsl_restart (globals/functions)
# Returns: 0 always
# Side-effects: Orchestrates entire DevBase installation process
main() {
  validate_environment
  validate_source_repository
  setup_installation_paths

  collect_user_configuration
  display_configuration_summary

  printf "%bPreparing system...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  prepare_system

  perform_installation

  write_installation_summary
  printf "\n"
  show_completion_message
  handle_wsl_restart
  return 0
}

# Custom hook system for organization-specific scripts
run_custom_hook() {
  local hook_name="$1"

  validate_not_empty "$hook_name" "Hook name" || return 1

  if [[ -z "${DEVBASE_CUSTOM_HOOKS}" ]]; then
    return 0 # No custom hooks directory configured
  fi

  local hook_file="${DEVBASE_CUSTOM_HOOKS}/${hook_name}.sh"

  if [[ -f "$hook_file" ]] && [[ -x "$hook_file" ]]; then
    show_progress info "Running $hook_name hook"

    if ! head -n1 "$hook_file" | grep -q '^#!/.*\(bash\|sh\)'; then
      show_progress warning "Hook missing proper shebang - skipped"
      return 1
    fi

    if ! bash -n "$hook_file" 2>/dev/null; then
      show_progress error "Hook has syntax errors - skipped"
      return 1
    fi

    # Run in subprocess for isolation (hooks can't pollute main script)
    if bash "$hook_file"; then
      show_progress success "$hook_name hook completed"
    else
      local hook_result=$?
      show_progress warning "$hook_name hook failed (exit code: $hook_result)"
      return 1
    fi
  fi

  return 0
}

main "$@"
