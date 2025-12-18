#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
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

# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/collect-user-preferences.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/process-templates.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-apt.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-snap.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-mise.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-custom.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-completions.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-shell.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/configure-services.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/setup-vscode.sh"

_VERSIONS_FILE=""
_DEVBASE_TEMP=$(mktemp -d /tmp/devbase.XXXXXX) || {
  echo "ERROR: Failed to create temp directory" >&2
  exit 1
}

readonly _DEVBASE_TEMP

if [[ -z "${DEVBASE_ROOT:-}" ]] || [[ -z "${DEVBASE_LIBS:-}" ]]; then
  echo "ERROR: Devbase environment not properly initialized" >&2
  exit 1
fi

# All required libraries are now sourced in setup.sh before this script
# This prevents duplicate sourcing and readonly variable conflicts

# Brief: Rotate backup directories to keep only one previous backup
# Params: None
# Uses: DEVBASE_BACKUP_DIR, HOME, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Removes old backups, renames current backup to .old
rotate_backup_directories() {
  # Rotate old backup if it exists (keep only one previous backup)
  if [[ -d "${DEVBASE_BACKUP_DIR:-}" ]]; then
    if [[ -d "${DEVBASE_BACKUP_DIR}.old" ]]; then
      # Safety check: ensure path is within user home
      if [[ -n "${DEVBASE_BACKUP_DIR:-}" ]] && [[ "${DEVBASE_BACKUP_DIR}.old" =~ ^${HOME}/ ]] && [[ ! "${DEVBASE_BACKUP_DIR}.old" =~ \.\. ]]; then
        rm -rf "${DEVBASE_BACKUP_DIR}.old"
      else
        show_progress warning "Refusing to remove unsafe backup path: ${DEVBASE_BACKUP_DIR}.old"
      fi
    fi
    mv "${DEVBASE_BACKUP_DIR}" "${DEVBASE_BACKUP_DIR}.old"
  fi

  # Clean up old timestamped backups
  for old_backup in "${HOME}"/.devbase_backup_*; do
    if [[ -d "$old_backup" ]]; then
      if [[ "$old_backup" =~ ^${HOME}/\.devbase_backup_[0-9]+$ ]]; then
        rm -rf "$old_backup"
      else
        show_progress warning "Skipping unexpected backup path: $old_backup"
      fi
    fi
  done

  return 0
}

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
# Uses: DEVBASE_FILES, DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, validate_var_set, show_progress (globals/functions)
# Returns: 0 always, 1 if validation fails
# Side-effects: Copies sudoers config file if proxy is configured
setup_sudo_and_system() {
  validate_var_set "DEVBASE_FILES" || return 1

  if [[ -n "${DEVBASE_PROXY_HOST:-}" && -n "${DEVBASE_PROXY_PORT:-}" ]] && [[ -f "${DEVBASE_FILES}/sudo-keep-proxyenv/sudokeepenv" ]]; then
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

  _VERSIONS_FILE="${DEVBASE_DOT}/.config/devbase/custom-tools.yaml"

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

_summary_header() {
  cat <<EOF
DEVBASE INSTALLATION SUMMARY
============================
Installation Date: $(date)
Environment: ${_DEVBASE_ENV:-unknown}
OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
Theme: ${DEVBASE_THEME}
DevBase Version: $(cat "${DEVBASE_CONFIG_DIR}/version" 2>/dev/null || echo "unknown")
$(if is_wsl; then echo "WSL Version: $(get_wsl_version 2>/dev/null || echo "unknown")"; fi)
EOF
}

_summary_system_config() {
  cat <<EOF

SYSTEM CONFIGURATION
====================
User: ${USER}
Home: ${HOME}
Shell: ${SHELL}
XDG_CONFIG_HOME: ${XDG_CONFIG_HOME}
XDG_DATA_HOME: ${XDG_DATA_HOME}
EOF
}

_summary_development_languages() {
  cat <<EOF

DEVELOPMENT LANGUAGES (mise-managed)
====================================
  • Node.js: $(command -v node >/dev/null && node --version | sed 's/^v//' || echo "not found")
  • Python: $(command -v python >/dev/null && python --version 2>&1 | cut -d' ' -f2 || echo "not found")
  • Go: $(command -v go >/dev/null && go version | cut -d' ' -f3 | sed 's/go//' || echo "not found")
  • Ruby: $(command -v ruby >/dev/null && ruby --version | cut -d' ' -f2 || echo "not found")
  • Rust: $(command -v rustc >/dev/null && rustc --version | cut -d' ' -f2 || echo "not found")
  • Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "not found")
  • Maven: $(command -v mvn >/dev/null && mvn --version 2>&1 | head -1 | cut -d' ' -f3 || echo "not found")
  • Gradle: $(command -v gradle >/dev/null && gradle --version 2>&1 | grep Gradle | cut -d' ' -f2 || echo "not found")
EOF
}

_summary_shell_terminal() {
  cat <<EOF

SHELL & TERMINAL
================
  • Fish: $(fish --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Starship: $(starship --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • Zellij: $(command -v zellij >/dev/null && zellij --version | cut -d' ' -f2 || echo "not found")
  • Zellij Autostart: $DEVBASE_ZELLIJ_AUTOSTART
  • Monaspace Nerd Font: $(if is_wsl; then echo "not applicable (WSL)"; elif [[ -d ~/.local/share/fonts/MonaspaceNerdFont ]]; then
    font_count=$(find ~/.local/share/fonts/MonaspaceNerdFont -name "*.ttf" -o -name "*.otf" 2>/dev/null | wc -l)
    if [[ $font_count -gt 0 ]]; then echo "installed ($font_count fonts)"; else echo "not installed"; fi
  else echo "not installed"; fi)
EOF
}

_summary_development_tools() {
  cat <<EOF

DEVELOPMENT TOOLS
=================
  • Git: $(git --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
  • Neovim: $(nvim --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • LazyVim: $([ -d ~/.config/nvim ] && echo "installed" || echo "not installed")
  • VS Code: $(code --version 2>/dev/null | head -1 || echo "not found")
  • Lazygit: $(lazygit --version 2>/dev/null | grep -oP 'version=\K[^,]+' || echo "not found")
  • Ripgrep: $(rg --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • Fd: $(fd --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Fzf: $(fzf --version 2>/dev/null | cut -d' ' -f1 || echo "not found")
  • Eza: $(eza --version 2>/dev/null | head -1 | grep -o 'v[0-9.]*' || echo "not found")
  • Bat: $(bat --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Delta: $(delta --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Jq: $(jq --version 2>/dev/null | sed 's/jq-//' || echo "not found")
  • Yq: $(yq --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
EOF
}

_summary_container_tools() {
  cat <<EOF

CONTAINER TOOLS
===============
  • Podman: $(podman --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Buildah: $(buildah --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Skopeo: $(skopeo --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
EOF
}

_summary_cloud_kubernetes() {
  cat <<EOF

CLOUD & KUBERNETES
==================
  • kubectl: $(kubectl version --client 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "not found")
  • oc: $(oc version --client 2>/dev/null | grep -o '[0-9.]*' | head -1 || echo "not found")
  • k9s: $(k9s version 2>/dev/null | grep Version | cut -d' ' -f2 || echo "not found")
EOF
}

_summary_optional_tools() {
  cat <<EOF

OPTIONAL TOOLS
==============
  • DBeaver: $([ -f ~/.local/bin/dbeaver ] && echo "installed" || echo "not installed")
  • KeyStore Explorer: $([ -f ~/.local/bin/kse ] && echo "installed" || echo "not installed")
  • IntelliJ IDEA: $(compgen -G ~/.local/share/JetBrains/IntelliJIdea* >/dev/null && echo "installed" || echo "not installed")
  • JMC: $(command -v jmc &>/dev/null && echo "installed" || echo "not installed")
EOF
}

_summary_git_config() {
  cat <<EOF

GIT CONFIGURATION
=================
  • Name: $(git config --global user.name 2>/dev/null || echo "not configured")
  • Email: $(git config --global user.email 2>/dev/null || echo "not configured")
  • Default Branch: $(git config --global init.defaultBranch 2>/dev/null || echo "not configured")
  • GPG Sign: $(git config --global commit.gpgsign 2>/dev/null || echo "not configured")
  • SSH Sign: $(git config --global gpg.format 2>/dev/null || echo "not configured")
EOF
}

_summary_ssh_config() {
  local key_type_upper
  key_type_upper=$(echo "${DEVBASE_SSH_KEY_TYPE:-ed25519}" | tr '[:lower:]' '[:upper:]')
  local key_path="${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}"

  cat <<EOF

SSH CONFIGURATION
=================
  • Key Type: ${key_type_upper}
  • Key Path: ${key_path}
  • Key Exists: $([ -f "${key_path}" ] && echo "yes" || echo "no")
  • Public Key Exists: $([ -f "${key_path}.pub" ] && echo "yes" || echo "no")
  • SSH Agent: $([ -n "${SSH_AUTH_SOCK:-}" ] && echo "configured" || echo "not configured")
EOF
}

_summary_network_config() {
  cat <<EOF

NETWORK CONFIGURATION
=====================
  • Proxy: $(if [[ -n "${DEVBASE_PROXY_HOST:-}" && -n "${DEVBASE_PROXY_PORT:-}" ]]; then echo "${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"; else echo "not configured"; fi)
  • Registry: $(if [[ -n "${DEVBASE_REGISTRY_HOST:-}" && -n "${DEVBASE_REGISTRY_PORT:-}" ]]; then echo "${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT}"; else echo "not configured"; fi)
EOF
}

_summary_mise_activation() {
  cat <<EOF

MISE ACTIVATION
===============
  • Mise Version: $(mise --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Config File: $([ -f ~/.config/mise/config.toml ] && echo "exists" || echo "missing")
  • Activation: Run 'eval "\$(mise activate bash)"' or restart shell
EOF
}

_summary_custom_config() {
  cat <<EOF

CUSTOM CONFIGURATION
====================
  • Custom Dir: $(if [[ -n "${DEVBASE_CUSTOM_DIR:-}" ]]; then echo "${DEVBASE_CUSTOM_DIR}"; else echo "not configured (using defaults)"; fi)
  • Custom Env: $(if [[ -n "${DEVBASE_CUSTOM_ENV:-}" ]]; then echo "loaded"; else echo "not loaded"; fi)
EOF
}

_summary_next_steps() {
  cat <<EOF

NEXT STEPS
==========
1. Restart your shell or run: exec fish
2. Verify installation: ./verify/verify-install-check.sh

For help and documentation: https://github.com/diggsweden/devbase-core
EOF
}

write_installation_summary() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  {
    _summary_header
    _summary_system_config
    _summary_development_languages
    _summary_shell_terminal
    _summary_development_tools
    _summary_container_tools
    _summary_cloud_kubernetes
    _summary_optional_tools
    _summary_git_config
    _summary_ssh_config
    _summary_network_config
    _summary_mise_activation
    _summary_custom_config
    _summary_next_steps
  } >"${DEVBASE_CONFIG_DIR}/install-summary.txt"

  return 0
}

show_completion_message() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  local box_width=70 # Wider to accommodate the summary path
  print_box_top "Installation Complete" "$box_width"
  print_box_line "Environment: ${_DEVBASE_ENV:-unknown}" "$box_width"
  print_box_line "Summary: ${DEVBASE_CONFIG_DIR}/install-summary.txt" "$box_width"
  print_box_line "Verify: ./verify/verify-install-check.sh (after new login)" "$box_width"

  if [[ "$GENERATED_SSH_PASSPHRASE" == "true" ]] && [[ -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" ]]; then
    local passphrase
    passphrase=$(cat "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" 2>/dev/null)
    if [[ -n "$passphrase" ]]; then
      print_box_line "" "$box_width"
      print_box_line "SSH Key Passphrase (save this!):" "$box_width"
      print_box_line "$passphrase" "$box_width"
      print_box_line "" "$box_width"
      print_box_line "To change: ssh-keygen -p -f ~/.ssh/${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}" "$box_width"
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

  # Check Secure Boot status after box (native Linux only)
  local sb_mode
  sb_mode=$(get_secure_boot_mode)

  # Display Secure Boot warnings outside the box
  case "$sb_mode" in
  disabled)
    printf "\n"
    show_progress warning "Secure Boot is currently disabled"
    show_progress warning "For better security, consider enabling it in your UEFI/EFI/BIOS settings"
    show_progress warning "If you're unsure what this means, please consult your system administrator"
    ;;
  setup)
    printf "\n"
    show_progress warning "Secure Boot is in Setup Mode (temporary state during key enrollment)"
    show_progress warning "Unsigned kernel modules work now but will be blocked after completing setup"
    show_progress warning "You should sign custom modules or change settings in UEFI/EFI/BIOS as soon as you can"
    show_progress warning "If you're unsure what this means, please consult your system administrator"
    ;;
  audit)
    printf "\n"
    show_progress warning "Secure Boot is in Audit Mode (logging violations but not blocking)"
    show_progress warning "Unsigned kernel modules currently work but violations are being logged"
    show_progress warning "You should sign custom modules or change settings in UEFI/EFI/BIOS as soon as you can"
    show_progress warning "If you're unsure what this means, please consult your system administrator"
    ;;
  esac

  return 0
}

configure_fonts_post_install() {
  # ===== Skip if not applicable =====
  # Only prompt on native Ubuntu when fonts were installed
  if [[ "${DEVBASE_FONTS_INSTALLED:-false}" != "true" ]] || [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    return 0
  fi

  # Source install-custom.sh early to get access to theme function
  if [[ -f "${DEVBASE_LIBS}/install-custom.sh" ]]; then
    # shellcheck disable=SC1091
    source "${DEVBASE_LIBS}/install-custom.sh"
  fi

  printf "\n"
  print_section "Terminal Configuration" "${DEVBASE_COLORS[BOLD_CYAN]}"
  printf "\n"

  # ===== Apply terminal theme =====
  if command -v gsettings &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    local profile_id
    profile_id=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [[ -n "$profile_id" ]] && [[ -n "${DEVBASE_THEME:-}" ]]; then
      if apply_gnome_terminal_theme "${DEVBASE_THEME}" "$profile_id" 2>/dev/null; then
        show_progress success "GNOME Terminal: Theme applied (${DEVBASE_THEME})"
      fi
    fi
  fi

  # ===== Check if font already configured =====
  local already_configured=false
  if command -v gsettings &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    local profile_id
    profile_id=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [[ -n "$profile_id" ]]; then
      local current_font
      current_font=$(gsettings get "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/" font 2>/dev/null || echo "")
      if [[ "$current_font" =~ Nerd.*Font ]]; then
        already_configured=true
      fi
    fi
  fi

  printf "\n"

  if [[ "$already_configured" == "true" ]]; then
    printf "  %b✓%b GNOME Terminal is already configured to use Nerd Font\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    return 0
  fi

  # ===== Prompt user to configure font =====
  printf "  %bNerd Font is available for use.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "  %bWould you like to configure your terminal to use it now?%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "\n"
  printf "  %bNote: Configuring now may affect this terminal session.%b\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_COLORS[NC]}"
  printf "  %bYou can also configure it manually later.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  printf "\n"

  if ask_yes_no "Configure terminal fonts now? (y/N)" "N"; then
    printf "\n"
    # configure_terminal_fonts now only sets the font (theme already applied above)
    configure_terminal_fonts

    printf "\n"
    printf "  %b⚠%b  %bIMPORTANT: Please restart your terminal to see font changes!%b\n" \
      "${DEVBASE_COLORS[YELLOW]}" \
      "${DEVBASE_COLORS[NC]}" \
      "${DEVBASE_COLORS[BOLD_YELLOW]}" \
      "${DEVBASE_COLORS[NC]}"
    printf "  %bClose and reopen your terminal application.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  else
    printf "\n"
    printf "  %b✓%b Font configuration skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
    printf "  %bTo configure later, set the font in your terminal settings to a Nerd Font%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
  fi
}

handle_wsl_restart() {
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
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
# Uses: install_apt_packages, install_snap_packages, install_mise_and_tools, install_fisher, install_nerd_fonts, install_lazyvim, install_jmc, install_oc_kubectl, install_vscode, install_dbeaver, install_keystore_explorer, install_intellij_idea, install_k3s, die, show_progress (functions)
# Returns: 0 always (critical failures call die)
# Side-effects: Installs all configured development tools
download_and_install_tools() {
  install_apt_packages || die "Failed to install APT packages"
  sudo_refresh
  install_snap_packages || die "Failed to install snap packages"
  sudo_refresh
  install_mise_and_tools || die "Failed to install mise and development tools"
  sudo_refresh
  install_fisher || show_progress warning "Fisher/fzf.fish setup failed (continuing)"
  install_nerd_fonts || show_progress warning "Nerd Font installation failed (continuing)"
  install_lazyvim || show_progress warning "LazyVim setup failed (continuing)"
  install_jmc || show_progress warning "JMC setup failed (continuing)"
  install_oc_kubectl || show_progress warning "oc/kubectl setup failed (continuing)"
  sudo_refresh
  install_vscode || show_progress warning "VS Code setup failed (continuing)"
  install_dbeaver || show_progress warning "DBeaver setup failed (continuing)"
  install_keystore_explorer || show_progress warning "KeyStore Explorer setup failed (continuing)"
  install_intellij_idea || show_progress warning "IntelliJ IDEA setup failed (continuing)"
  sudo_refresh
  install_k3s || show_progress warning "k3s setup failed (continuing)"

  return 0
}

# Brief: Apply user configurations (dotfiles, SSH, Git, VS Code)
# Params: None
# Uses: process_and_copy_dotfiles, configure_ssh, configure_git, configure_git_hooks, setup_vscode, DEVBASE_VSCODE_INSTALL, die, show_progress (functions/globals)
# Returns: 0 always (critical failures call die)
# Side-effects: Processes templates, configures SSH/Git
apply_configurations() {

  process_and_copy_dotfiles || die "Failed to process dotfiles"
  configure_ssh || die "Failed to configure SSH"
  configure_git || die "Failed to configure Git"
  configure_git_hooks || die "Failed to configure git hooks"

  # Setup VS Code extensions if VS Code is installed or available
  # On WSL: installs Remote-WSL extension and sets up vscode-server extensions
  # On native: installs extensions to local VS Code
  if [[ "${DEVBASE_VSCODE_INSTALL}" == "true" ]] || command -v code &>/dev/null; then
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

  # Disable pcscd (smart card daemon) by default - enable manually when needed
  if ! is_wsl && command -v pcscd &>/dev/null; then
    sudo systemctl disable pcscd &>/dev/null || true
  fi

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

_get_theme_display_name() {
  local theme="$1"
  case "$theme" in
  everforest-dark) echo "Everforest Dark" ;;
  everforest-light) echo "Everforest Light" ;;
  catppuccin-mocha) echo "Catppuccin Mocha" ;;
  catppuccin-latte) echo "Catppuccin Latte" ;;
  tokyonight-night) echo "Tokyo Night" ;;
  tokyonight-day) echo "Tokyo Night Day" ;;
  gruvbox-dark) echo "Gruvbox Dark" ;;
  gruvbox-light) echo "Gruvbox Light" ;;
  nord) echo "Nord" ;;
  dracula) echo "Dracula" ;;
  solarized-dark) echo "Solarized Dark" ;;
  solarized-light) echo "Solarized Light" ;;
  *) echo "$theme" ;;
  esac
}

_get_font_display_name() {
  local font="$1"
  case "$font" in
  jetbrains-mono) echo "JetBrains Mono Nerd Font" ;;
  firacode) echo "Fira Code Nerd Font" ;;
  cascadia-code) echo "Cascadia Code Nerd Font" ;;
  monaspace) echo "Monaspace Nerd Font" ;;
  *) echo "$font" ;;
  esac
}

_display_git_config() {
  print_box_line "Git Configuration:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • Author: ${DEVBASE_GIT_AUTHOR}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • Email: ${DEVBASE_GIT_EMAIL}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_theme_config() {
  local theme_display
  local font_display
  theme_display=$(_get_theme_display_name "${DEVBASE_THEME}")
  print_box_line "Theme:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • ${theme_display}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  # Only display font on native Linux (WSL manages fonts via Windows Terminal)
  if [[ "${_DEVBASE_ENV}" != "wsl-ubuntu" ]] && [[ -n "${DEVBASE_FONT:-}" ]]; then
    validate_var_set "DEVBASE_FONT" || return 1
    font_display=$(_get_font_display_name "${DEVBASE_FONT}")
    print_box_line "Font:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • ${font_display}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
}

_display_ssh_config() {
  print_box_line "SSH Key:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${DEVBASE_SSH_KEY_ACTION}" == "new" ]]; then
    print_box_line "  • Action: Generate new key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Location: ${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    if [[ -n "${DEVBASE_SSH_PASSPHRASE:-}" ]]; then
      print_box_line "  • Protection: With passphrase" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    else
      print_box_line "  • Protection: No passphrase" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    fi
  elif [[ "${DEVBASE_SSH_KEY_ACTION}" == "skip" ]]; then
    print_box_line "  • Action: No SSH key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Action: Keep existing key" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Location: ${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_editor_config() {
  print_box_line "Editor & Shell:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  if [[ "${EDITOR}" == "nvim" ]]; then
    print_box_line "  • Default editor: Neovim" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Shell bindings: Vim mode" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Default editor: Nano" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    print_box_line "  • Shell bindings: Emacs mode" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_clipboard_config() {
  local clipboard_util
  clipboard_util=$(detect_clipboard_utility 2>/dev/null || echo "not detected")
  print_box_line "Clipboard:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "  • ${clipboard_util}" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_ide_config() {
  print_box_line "IDE & Editor Extensions:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  if [[ "${DEVBASE_VSCODE_INSTALL}" == "true" ]]; then
    print_box_line "  • VS Code: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
    if [[ "${DEVBASE_VSCODE_EXTENSIONS}" == "true" ]]; then
      print_box_line "    - Extensions: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
      if [[ "${DEVBASE_VSCODE_NEOVIM}" == "true" ]]; then
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

  if [[ "$DEVBASE_INSTALL_LAZYVIM" == "true" ]]; then
    print_box_line "  • LazyVim: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • LazyVim: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi

  if [[ "$DEVBASE_INSTALL_INTELLIJ" == "true" ]]; then
    print_box_line "  • IntelliJ IDEA: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • IntelliJ IDEA: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi

  if [[ "$DEVBASE_INSTALL_JMC" == "true" ]]; then
    print_box_line "  • JDK Mission Control: Yes" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • JDK Mission Control: No" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi

  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_tools_config() {
  print_box_line "Tools & Integrations:" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  if [[ "$DEVBASE_ZELLIJ_AUTOSTART" == "true" ]]; then
    print_box_line "  • Zellij auto-start: Enabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Zellij auto-start: Disabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi

  if [[ "$DEVBASE_ENABLE_GIT_HOOKS" == "true" ]]; then
    print_box_line "  • Global git hooks: Enabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  else
    print_box_line "  • Global git hooks: Disabled" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  fi

  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
}

_display_installation_overview() {
  printf "\n"
  print_box_top "Installation Overview" 60 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_line "• Estimated time: 10-15 minutes" 60
  print_box_line "• Disk space required: ~6GB" 60
  print_box_line "• Internet connection required" 60
  print_box_line "• Sudo password will be requested before install" 60
  print_box_bottom 60 "${DEVBASE_COLORS[BOLD_CYAN]}"
}

display_configuration_summary() {
  validate_var_set "DEVBASE_GIT_AUTHOR" || return 1
  validate_var_set "DEVBASE_GIT_EMAIL" || return 1
  validate_var_set "DEVBASE_THEME" || return 1
  validate_var_set "DEVBASE_SSH_KEY_ACTION" || return 1
  validate_var_set "DEVBASE_SSH_KEY_NAME" || return 1

  printf "\n"
  print_box_top "Configuration Summary" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"
  print_box_line "" 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  _display_git_config
  _display_theme_config
  _display_ssh_config
  _display_editor_config
  _display_clipboard_config
  _display_ide_config
  _display_tools_config

  print_box_bottom 60 "${DEVBASE_COLORS[BOLD_GREEN]}"

  _display_installation_overview

  printf "\n"
  if ! ask_yes_no "Ready to install with these settings? (Y/n)" "Y"; then
    show_progress info "Installation cancelled"
    exit 0
  fi
}

# Brief: Prepare system by ensuring sudo access, user directories and system configuration
# Params: None
# Uses: USER, show_progress, die, ensure_user_dirs, setup_sudo_and_system, install_certificates, persist_devbase_repos (globals/functions)
# Returns: 0 always (dies on failure)
# Side-effects: Prompts for sudo password, installs certs, clones repos, creates user directories, configures sudo for proxy
prepare_system() {
  # PHASE 1: System Preparation (first actual changes)
  # Check/obtain sudo access right before we need it (after user answers questions)
  if ! sudo -n true 2>/dev/null; then
    show_progress info "Sudo access required for system package installation"
    show_progress info "Please enter your password when prompted"

    if ! sudo -v; then
      die "Sudo access required to install system packages"
    fi
    show_progress success "Sudo access granted"
  fi

  # Install certificates FIRST - required for git clone to custom registries
  # Must happen before persist_devbase_repos which may clone from internal git servers
  printf "\n%bInstalling certificates...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  install_certificates || die "Failed to install certificates"

  # Persist devbase repos to ~/.local/share/devbase/ for update support
  # Done after certs so git can trust custom registry SSL certificates
  persist_devbase_repos || show_progress warning "Could not persist devbase repos (continuing)"

  ensure_user_dirs

  setup_sudo_and_system
}

# Brief: Perform complete DevBase installation (tools, configs, services, hooks)
# Params: None
# Uses: DEVBASE_COLORS, _DEVBASE_CUSTOM_HOOKS, download_and_install_tools, apply_configurations, configure_system_and_shell, finalize_installation, run_custom_hook, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Installs tools, applies configs, runs custom hooks
perform_installation() {
  # Note: Certificates are installed in prepare_system() before this function
  # Export NODE_EXTRA_CA_CERTS to ensure npm/mise respect custom certificates
  if [[ -f "/etc/ssl/certs/ca-certificates.crt" ]]; then
    export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
  fi

  printf "\n%bInstalling development tools...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  download_and_install_tools

  sudo_refresh
  printf "\n%bApplying configurations...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  apply_configurations

  sudo_refresh
  printf "\n%bConfiguring system services...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  configure_system_and_shell

  if validate_custom_dir "_DEVBASE_CUSTOM_HOOKS" "Custom hooks directory"; then
    run_custom_hook "post-configuration" || show_progress warning "Post-configuration hook failed"
  fi

  sudo_refresh
  printf "\n%bFinalizing installation...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  finalize_installation

  if validate_custom_dir "_DEVBASE_CUSTOM_HOOKS" "Custom hooks directory"; then
    run_custom_hook "post-install" || show_progress warning "Post-install hook failed, continuing..."
  fi
}

# Brief: Main installation orchestration function
# Params: None
# Uses: DEVBASE_COLORS, rotate_backup_directories, validate_environment, validate_source_repository, setup_installation_paths, run_preflight_checks, collect_user_configuration, display_configuration_summary, prepare_system, perform_installation, write_installation_summary, show_completion_message, handle_wsl_restart (globals/functions)
# Returns: 0 always
# Side-effects: Orchestrates entire DevBase installation process
main() {
  rotate_backup_directories
  validate_environment
  validate_source_repository
  setup_installation_paths

  # Run all pre-flight checks (Ubuntu version, disk space, paths, GitHub token)
  # Note: Sudo check happens later in prepare_system() to avoid timeout issues
  printf "\n"
  run_preflight_checks || return 1

  collect_user_configuration
  display_configuration_summary

  printf "%bPreparing system...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
  prepare_system

  perform_installation

  write_installation_summary
  printf "\n"
  show_completion_message
  configure_fonts_post_install
  handle_wsl_restart
  return 0
}

# Custom hook system for organization-specific scripts
run_custom_hook() {
  local hook_name="$1"

  validate_not_empty "$hook_name" "Hook name" || return 1

  # Check if custom hooks directory is configured
  if ! validate_custom_dir "_DEVBASE_CUSTOM_HOOKS" "Custom hooks directory"; then
    return 0 # No custom hooks directory configured
  fi

  local hook_file="${_DEVBASE_CUSTOM_HOOKS}/${hook_name}.sh"

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
