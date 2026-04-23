#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# shellcheck disable=SC2153 # WT_* variables are defined in ui-helpers-whiptail.sh

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# shellcheck disable=SC1091 # Loaded via DEVBASE_ROOT at runtime
source "${DEVBASE_ROOT}/libs/install-context.sh"
source "${DEVBASE_ROOT}/libs/theme-registry.sh"
source "${DEVBASE_ROOT}/libs/font-registry.sh"

set -Euo pipefail

# shellcheck disable=SC1091 # Loaded via DEVBASE_ROOT at runtime
source "${DEVBASE_ROOT}/libs/install-errors.sh"
# shellcheck disable=SC1091 # Loaded via DEVBASE_ROOT at runtime
source "${DEVBASE_ROOT}/libs/install-phases.sh"

# Source user preferences collector based on TUI mode
# DEVBASE_TUI_MODE is set by select_tui_mode() in setup.sh before sourcing this file
case "${DEVBASE_TUI_MODE:-whiptail}" in
gum)
  # Modern gum-based TUI (best experience)
  # shellcheck disable=SC1091 # File exists at runtime
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-gum.sh"
  ;;
*)
  # Whiptail TUI (default fallback, also used for non-interactive)
  # shellcheck disable=SC1091 # File exists at runtime
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  ;;
esac
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/pkg/pkg-manager.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-snap.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/install-mise.sh"
# shellcheck disable=SC1091 # File exists at runtime
source "${DEVBASE_ROOT}/libs/summary.sh"

if [[ -z "${_DEVBASE_TEMP:-}" ]] || [[ ! -d "${_DEVBASE_TEMP}" ]] || [[ ! -w "${_DEVBASE_TEMP}" ]]; then
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    whiptail --backtitle "$WT_BACKTITLE" --title "Error" \
      --msgbox "Temp directory not initialized correctly$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH" 2>/dev/null || true
  else
    echo "ERROR: Temp directory not initialized correctly (_DEVBASE_TEMP)" >&2
  fi
  exit 1
fi

if [[ -z "${DEVBASE_ROOT:-}" ]] || [[ -z "${DEVBASE_LIBS:-}" ]]; then
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    whiptail --backtitle "$WT_BACKTITLE" --title "Error" \
      --msgbox "DevBase environment not properly initialized$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH" 2>/dev/null || true
  else
    echo "ERROR: Devbase environment not properly initialized" >&2
  fi
  exit 1
fi

# Common libraries are sourced in setup.sh before this script
# This avoids duplicate sourcing and readonly variable conflicts

# Brief: Rotate backup directories to keep only one previous backup
# Params: None
# Uses: DEVBASE_BACKUP_DIR, HOME, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Removes old backups, renames current backup to .old
rotate_backup_directories() {
  # Rotate old backup if it exists (keep only one previous backup)
  if [[ -d "${DEVBASE_BACKUP_DIR:-}" ]]; then
    if [[ -d "${DEVBASE_BACKUP_DIR}.old" ]]; then
      safe_rm_rf "$HOME" "${DEVBASE_BACKUP_DIR}.old" || true
    fi
    mv "${DEVBASE_BACKUP_DIR}" "${DEVBASE_BACKUP_DIR}.old"
  fi

  # Clean up old timestamped backups
  for old_backup in "${HOME}"/.devbase_backup_*; do
    if [[ -d "$old_backup" ]]; then
      if [[ "$old_backup" =~ ^${HOME}/\.devbase_backup_[0-9]+$ ]]; then
        safe_rm_rf "$HOME" "$old_backup" || true
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
    local sudoers_src="${DEVBASE_FILES}/sudo-keep-proxyenv/sudokeepenv"
    local sudoers_dst="/etc/sudoers.d/sudokeepenv"
    local sudoers_tmp
    sudoers_tmp=$(mktemp) || return 1
    # shellcheck disable=SC2064
    trap "rm -f '$sudoers_tmp'" RETURN

    cp "$sudoers_src" "$sudoers_tmp"
    if ! sudo visudo -c -f "$sudoers_tmp" &>/dev/null; then
      show_progress error "Invalid sudoers proxy config (refusing to install)"
      return 1
    fi

    if ! sudo install -m 0440 "$sudoers_tmp" "$sudoers_dst"; then
      show_progress error "Failed to install sudoers proxy config"
      return 1
    fi

    if ! sudo visudo -c -f "$sudoers_dst" &>/dev/null; then
      sudo rm -f "$sudoers_dst"
      show_progress error "Sudoers proxy config failed validation and was removed"
      return 1
    fi

    show_progress success "Sudo proxy preservation configured"
  fi

  return 0
}

# Brief: Validate devbase-core source repository structure
# Params: None
# Uses: validate_dir_exists, die (functions)
# Returns: 0 on success (dies on failure)
# Side-effects: Checks for required directories, exits if missing
validate_source_repository() {
  local required_dirs=(
    "${DEVBASE_ROOT}/devbase_files"
    "${DEVBASE_ROOT}/dot"
    "${DEVBASE_ROOT}/environments"
    "${DEVBASE_ROOT}/libs"
  )

  for dir in "${required_dirs[@]}"; do
    validate_dir_exists "$dir" "Required directory" || die "Directory missing: $dir (invalid DEVBASE_ROOT?)"
  done

  return 0
}

# Brief: Initialize installation file paths and validate temp directory
# Params: None
# Uses: DEVBASE_DOT, _DEVBASE_TEMP, validate_var_set (globals/functions)
# Returns: 0 on success, 1 if validation fails
# Side-effects: Validates required paths
setup_installation_paths() {
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "_DEVBASE_TEMP" || return 1

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
      show_progress warning "Removing all Podman containers, images, and volumes"
      podman system reset --force || true
      files_cleaned=$((files_cleaned + ${podman_size:-0}))

    fi
  fi

  backup_if_exists "${XDG_CONFIG_HOME}/nvim/.git" "nvim-git-old"

  pkg_cleanup

  show_progress success "Cleanup complete"
  return 0
}

# Brief: Show completion message using gum styling
_show_completion_message_gum() {
  echo
  gum style \
    --foreground 82 \
    --border double \
    --border-foreground 82 \
    --padding "1 2" \
    --margin "1 0" \
    "Installation Complete"

  echo
  gum style --foreground 240 "Summary"
  echo "  Environment: ${_DEVBASE_ENV:-unknown}"
  if [[ ${#INSTALL_WARNINGS[@]} -gt 0 ]]; then
    echo "  Status:      Completed with warnings"
  else
    echo "  Status:      Completed successfully"
  fi
  echo "  Summary:     ${DEVBASE_CONFIG_DIR}/install-summary.txt"
  echo "  Verify:      ./verify/verify-install-check.sh"
  echo

  if [[ "${GENERATED_SSH_PASSPHRASE:-}" == "true" ]] && [[ -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" ]]; then
    local passphrase
    passphrase=$(cat "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" 2>/dev/null)
    if [[ -n "$passphrase" ]]; then
      gum style --foreground 214 "SSH Key Passphrase (save this!)"
      echo "  $passphrase"
      echo
      gum style --foreground 240 "To change:"
      echo "  ssh-keygen -p -f ~/.ssh/${DEVBASE_SSH_KEY_NAME:-$(get_default_ssh_key_name)}"
      echo
    fi
    rm -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
  fi

  gum style --foreground 240 "Useful Commands"
  echo "  devbase-theme <name>       Change color theme"
  echo "  devbase-update             Update devbase installation"
  if [[ "${DEVBASE_VSCODE_EXTENSIONS:-}" == "true" ]]; then
    echo "  devbase-vscode-extensions  Install VS Code extensions"
  fi
  echo "  devbase-smartcard          Configure smart card support"
  echo "  devbase-citrix             Configure Citrix Workspace"
  echo

  gum style --foreground 240 "Next Steps"
  echo "  1. Restart your shell or run: exec fish"
  echo "  2. Run verification: ./verify/verify-install-check.sh"
  echo

  # Check Secure Boot status
  local sb_mode
  sb_mode=$(get_secure_boot_mode)

  case "$sb_mode" in
  disabled)
    echo
    gum style --foreground 196 "⚠ Secure Boot seems to be disabled on this machine - enable it in UEFI/BIOS settings"
    ;;
  setup | audit)
    echo
    gum style --foreground 196 "⚠ Secure Boot is in $sb_mode mode - complete the setup in UEFI/BIOS"
    ;;
  esac
}

# Brief: Show completion message using whiptail msgbox
_show_completion_message_whiptail() {
  local message=""

  message+="Environment: ${_DEVBASE_ENV:-unknown}\n"
  if [[ ${#INSTALL_WARNINGS[@]} -gt 0 ]]; then
    message+="Status: Completed with warnings\n"
  else
    message+="Status: Completed successfully\n"
  fi
  message+="Summary: ${DEVBASE_CONFIG_DIR}/install-summary.txt\n"
  message+="Verify: ./verify/verify-install-check.sh\n"

  message+="\n"

  if [[ "${GENERATED_SSH_PASSPHRASE:-}" == "true" ]] && [[ -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" ]]; then
    local passphrase
    passphrase=$(cat "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp" 2>/dev/null)
    if [[ -n "$passphrase" ]]; then
      message+="SSH Key Passphrase (save this!):\n"
      message+="  $passphrase\n"
      message+="\n"
    fi
    rm -f "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
  fi

  message+="Useful Commands:\n"
  message+="  devbase-theme <name>       Change color theme\n"
  message+="  devbase-update             Update devbase\n"
  if [[ "${DEVBASE_VSCODE_EXTENSIONS:-}" == "true" ]]; then
    message+="  devbase-vscode-extensions  Install VS Code extensions\n"
  fi
  message+="  devbase-smartcard          Configure smart card\n"
  message+="  devbase-citrix             Configure Citrix\n"
  message+="\n"

  message+="Next Steps:\n"
  message+="  1. Restart your terminal (or open a new tab)\n"
  message+="  2. Verify: ./verify/verify-install-check.sh\n"

  # Check Secure Boot status
  local sb_mode
  sb_mode=$(get_secure_boot_mode)

  case "$sb_mode" in
  disabled)
    message+="\n⚠ Secure Boot seems to be disabled - enable in UEFI/BIOS"
    ;;
  setup | audit)
    message+="\n⚠ Secure Boot in $sb_mode mode - complete setup in UEFI/BIOS"
    ;;
  esac

  # Show completion in whiptail msgbox with scrolltext for long content
  whiptail --backtitle "$WT_BACKTITLE" --title "Installation Complete" \
    --scrolltext --msgbox "$message$WT_NAV_HINTS" "$WT_HEIGHT_XLARGE" "$WT_WIDTH"
}

show_completion_message() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  # Use gum for completion message when available
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    _show_completion_message_gum
    return 0
  fi

  # Whiptail mode - show installation summary log first
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    _wt_show_final_log
  fi

  # Then show completion message
  _show_completion_message_whiptail

  # Clear screen after whiptail exits to remove graphical residue
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    clear
  fi
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

  show_phase "Terminal Configuration"

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

  if [[ "$already_configured" == "true" ]]; then
    show_progress success "GNOME Terminal is already configured to use Nerd Font"
    return 0
  fi

  # ===== Prompt user to configure font =====
  # In whiptail mode, use dialog; in gum mode, use terminal output
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    if whiptail --backtitle "$WT_BACKTITLE" --title "Terminal Font" \
      --yesno "Nerd Font is available.\n\nWould you like to configure your terminal to use it now?\n\nNote: You can configure it manually later.$WT_NAV_HINTS" "$WT_HEIGHT_MEDIUM" "$WT_WIDTH"; then
      configure_terminal_fonts
      whiptail --backtitle "$WT_BACKTITLE" --title "Font Configured" \
        --msgbox "Font configured!\n\nPlease restart your terminal to see the changes.$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH"
    else
      show_progress info "Font configuration skipped"
    fi
  else
    # Gum mode - use original terminal output
    tui_blank_line
    tui_printf "  %bNerd Font is available for use.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    tui_printf "  %bWould you like to configure your terminal to use it now?%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    tui_blank_line
    tui_printf "  %bNote: Configuring now may affect this terminal session.%b\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_COLORS[NC]}"
    tui_printf "  %bYou can also configure it manually later.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    tui_blank_line

    if ask_yes_no "Configure terminal fonts now? (y/N)" "N"; then
      tui_blank_line
      configure_terminal_fonts
      tui_blank_line
      tui_printf "  %b⚠%b  %bIMPORTANT: Please restart your terminal to see font changes!%b\n" \
        "${DEVBASE_COLORS[YELLOW]}" \
        "${DEVBASE_COLORS[NC]}" \
        "${DEVBASE_COLORS[BOLD_YELLOW]}" \
        "${DEVBASE_COLORS[NC]}"
      tui_printf "  %bClose and reopen your terminal application.%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    else
      tui_blank_line
      tui_printf "  %b✓%b Font configuration skipped\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}"
      tui_printf "  %bTo configure later, set the font in your terminal settings to a Nerd Font%b\n" "${DEVBASE_COLORS[DIM]}" "${DEVBASE_COLORS[NC]}"
    fi
  fi
}

handle_wsl_restart() {
  if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
    show_progress info "[WSL-specific] WSL must restart to apply all changes"

    # In whiptail mode, use dialog
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
      whiptail --backtitle "$WT_BACKTITLE" --title "WSL Restart Required" \
        --msgbox "WSL must restart to apply all changes.\n\nPress OK to shutdown WSL now.$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH"
    else
      # Gum mode - use terminal output
      tui_blank_line
      tui_printf "  %b%b%bPress ENTER to shutdown WSL now...%b" \
        "${DEVBASE_COLORS[BOLD_YELLOW]}" \
        "${DEVBASE_COLORS[BLINK_SLOW]}" \
        "${DEVBASE_COLORS[BOLD]}" \
        "${DEVBASE_COLORS[NC]}"
      read -r
      tui_blank_line
    fi

    if ! command -v wsl.exe &>/dev/null; then
      show_progress warning "wsl.exe not found; skipping WSL shutdown"
      return 0
    fi

    show_progress info "Shutting down WSL..."
    wsl.exe --shutdown
    return 0
  fi
  return 0
}

# Brief: Install all development tools (system packages, app store, mise, custom tools)
# Params: None
# Uses: install_system_packages, install_app_store_packages, install_mise_and_tools, install_fisher, install_nerd_fonts, install_lazyvim, install_jmc, install_oc_kubectl, install_vscode, install_dbeaver, install_keystore_explorer, install_intellij_idea, install_k3s, die, show_progress (functions)
# Returns: 0 always (critical failures call die)
# Side-effects: Installs all configured development tools
download_and_install_tools() {
  install_system_packages || die "Failed to install system packages"
  sudo_refresh
  install_firefox_native || show_progress warning "Firefox installation failed (continuing)"
  sudo_refresh
  install_app_store_packages || die "Failed to install app store packages"
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
# Uses: configure_podman_service, configure_podman_compose_provider, configure_clamav_service, configure_ufw, configure_wayland_service, disable_kubernetes_services, set_system_limits, configure_fish_interactive, configure_completions, DEVBASE_LIBS, die, show_progress (functions/globals)
# Returns: 0 always (critical failures call die)
# Side-effects: Enables services, configures shell, installs WT themes on WSL
configure_system_and_shell() {
  configure_docker_proxy || show_progress warning "Docker proxy configuration failed (continuing)"
  configure_podman_service || die "Failed to configure podman service"
  configure_podman_compose_provider || show_progress warning "Podman compose provider link failed (continuing)"
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
    source "${DEVBASE_LIBS}/install-windows-terminal-themes.sh"
    local wt_output
    if wt_output=$(install_windows_terminal_themes 2>&1); then
      if echo "$wt_output" | grep -q "✓"; then
        show_progress success "Windows Terminal themes configured"
      else
        show_progress warning "Windows Terminal themes installation incomplete"
      fi
    else
      show_progress warning "Windows Terminal themes installation failed (continuing)"
    fi
  fi

  return 0
}

# Brief: Configure Docker daemon proxy settings (systemd drop-in)
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS, HTTP_PROXY, HTTPS_PROXY, NO_PROXY
# Returns: 0 always (best-effort)
configure_docker_proxy() {
  local http_proxy="${HTTP_PROXY:-}"
  local https_proxy="${HTTPS_PROXY:-}"
  local no_proxy="${NO_PROXY:-}"

  if [[ -z "$http_proxy" && -n "${DEVBASE_PROXY_HOST:-}" && -n "${DEVBASE_PROXY_PORT:-}" ]]; then
    http_proxy="http://${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
  fi

  if [[ -z "$https_proxy" && -n "${DEVBASE_PROXY_HOST:-}" && -n "${DEVBASE_PROXY_PORT:-}" ]]; then
    https_proxy="http://${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
  fi

  if [[ -z "$no_proxy" && -n "${DEVBASE_NO_PROXY_DOMAINS:-}" ]]; then
    no_proxy="${DEVBASE_NO_PROXY_DOMAINS}"
  fi

  if [[ -z "$http_proxy" && -z "$https_proxy" && -z "$no_proxy" ]]; then
    return 0
  fi

  if ! command -v systemctl &>/dev/null; then
    show_progress info "systemctl not available; skipping Docker proxy configuration"
    return 0
  fi

  show_progress info "Configuring Docker daemon proxy..."

  local docker_dropin_dir="/etc/systemd/system/docker.service.d"
  local docker_dropin_file="${docker_dropin_dir}/http-proxy.conf"

  if ! sudo mkdir -p "$docker_dropin_dir"; then
    show_progress warning "Failed to create Docker systemd drop-in directory"
    return 0
  fi

  if [[ -f "$docker_dropin_file" ]]; then
    show_progress info "Docker proxy drop-in already exists, skipping"
    return 0
  fi

  {
    echo "[Service]"
    [[ -n "$http_proxy" ]] && echo "Environment=\"HTTP_PROXY=${http_proxy}/\""
    [[ -n "$https_proxy" ]] && echo "Environment=\"HTTPS_PROXY=${https_proxy}/\""
    [[ -n "$no_proxy" ]] && echo "Environment=\"NO_PROXY=${no_proxy}\""
  } | sudo tee "$docker_dropin_file" >/dev/null

  if systemctl list-unit-files docker.service &>/dev/null; then
    sudo systemctl daemon-reload
    sudo systemctl restart docker || show_progress warning "Docker restart failed"
    show_progress success "Docker proxy configured"
  else
    show_progress info "Docker service not found; proxy drop-in created for future installs"
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
  get_theme_display_name "$theme"
}

_get_font_display_name() {
  local font="$1"
  get_font_display_name "$font"
}

display_configuration_summary() {
  # Gum and whiptail handle their own summary and confirmation in collect_user_configuration
  # This function is now a no-op but kept for API compatibility
  return 0
}

# Brief: Bootstrap tooling needed for configuration parsing
# Params: None
# Uses: install_mise, show_progress, die (functions)
# Returns: 0 on success, dies on failure
bootstrap_for_configuration() {
  show_progress step "Bootstrapping configuration tooling"
  install_mise || die "Failed to install mise for configuration"

  if ! command -v yq &>/dev/null || ! yq --version >/dev/null 2>&1; then
    show_progress warning "yq missing after mise bootstrap, attempting recovery"

    local mise_path=""
    if command -v mise &>/dev/null; then
      mise_path="$(command -v mise)"
    elif [[ -x "${HOME}/.local/bin/mise" ]]; then
      mise_path="${HOME}/.local/bin/mise"
    fi

    # Ensure common mise paths are available in this shell session.
    local mise_shims="${MISE_DATA_DIR:-${HOME}/.local/share/mise}/shims"
    [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:${PATH}"
    [[ -d "$mise_shims" && ":${PATH}:" != *":${mise_shims}:"* ]] && export PATH="${mise_shims}:${PATH}"

    if [[ -n "$mise_path" ]]; then
      [[ -f "${DEVBASE_ROOT}/.mise.toml" ]] && "$mise_path" trust "${DEVBASE_ROOT}/.mise.toml" >/dev/null 2>&1 || true
      "$mise_path" --no-config use -g "aqua:mikefarah/yq@v4.52.4" --yes >/dev/null 2>&1 || true

      if declare -f _mise_apply_path_from_activate &>/dev/null; then
        _mise_apply_path_from_activate "$mise_path" >/dev/null 2>&1 || true
      fi
    fi
  fi

  if ! command -v yq &>/dev/null || ! yq --version >/dev/null 2>&1; then
    die "yq not available after mise bootstrap (tried auto-recovery)"
  fi
}

# Brief: Prepare system by ensuring sudo access, user directories and system configuration
# Params: None
# Uses: USER, show_progress, die, ensure_user_dirs, setup_sudo_and_system, persist_devbase_repos (globals/functions)
# Returns: 0 always (dies on failure)
# Side-effects: Prompts for sudo password, clones repos, creates user directories, configures sudo for proxy
prepare_system() {
  # PHASE 1: System Preparation (first actual changes)
  # Sudo access was already obtained in run_preflight_checks
  # Just refresh the sudo timestamp to keep it alive
  if ! sudo -n true 2>/dev/null; then
    # Sudo timed out - need to re-acquire
    # In whiptail mode, stop gauge, get sudo properly, restart gauge
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
      stop_installation_progress
      whiptail --backtitle "$WT_BACKTITLE" --title "Sudo Access Required" \
        --msgbox "Sudo session expired. Please re-enter your password.$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH"
      clear
      if ! sudo -v; then
        die "Sudo access required to install system packages"
      fi
      start_installation_progress
      show_phase "Preparing system..."
    else
      show_progress info "Refreshing sudo access..."
      sudo -v || die "Sudo access required to install system packages"
    fi
  fi

  # Persist devbase repos to ~/.local/share/devbase/ for update support
  # Certificates are installed earlier to allow trusted cloning
  persist_devbase_repos || add_install_warning "Could not persist devbase repos (continuing)"

  ensure_user_dirs

  setup_sudo_and_system || die "Failed to configure sudo proxy preservation"

}

# Brief: Perform complete DevBase installation (tools, configs, services, hooks)
# Params: None
# Uses: DEVBASE_COLORS, _DEVBASE_CUSTOM_HOOKS, download_and_install_tools, apply_configurations, configure_system_and_shell, finalize_installation, run_custom_hook, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Installs tools, applies configs, runs custom hooks
perform_installation() {
  # Note: Certificates are installed early in setup.sh before downloads
  # Export NODE_EXTRA_CA_CERTS to ensure npm/mise respect custom certificates
  if [[ -f "/etc/ssl/certs/ca-certificates.crt" ]]; then
    export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
  fi

  show_phase "Installing development tools..."
  download_and_install_tools

  sudo_refresh
  show_phase "Applying configurations..."
  apply_configurations

  sudo_refresh
  show_phase "Configuring system services..."
  configure_system_and_shell

  local hooks_dir
  hooks_dir=$(get_custom_hooks_dir)
  if [[ -n "$hooks_dir" && -d "$hooks_dir" ]]; then
    run_custom_hook "post-configuration" || add_install_warning "Post-configuration hook failed"
  fi

  sudo_refresh
  show_phase "Finalizing installation..."
  finalize_installation

  hooks_dir=$(get_custom_hooks_dir)
  if [[ -n "$hooks_dir" && -d "$hooks_dir" ]]; then
    run_custom_hook "post-install" || add_install_warning "Post-install hook failed"
  fi

}

set_default_values() {
  # Export variables that were initialized in IMPORT section with defaults
  export DEVBASE_PROXY_HOST DEVBASE_PROXY_PORT DEVBASE_NO_PROXY_DOMAINS
  export DEVBASE_REGISTRY_HOST DEVBASE_REGISTRY_PORT
  export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_BIN_HOME
  export DEVBASE_THEME DEVBASE_FONT

  # Define DevBase directories using XDG variables
  export DEVBASE_CACHE_DIR="${XDG_CACHE_HOME}/devbase"
  export DEVBASE_CONFIG_DIR="${XDG_CONFIG_HOME}/devbase"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"

  # Debug output if DEVBASE_DEBUG environment variable is set
  if [[ "${DEVBASE_DEBUG}" == "1" ]]; then
    show_progress info "Debug mode enabled"
    show_progress info "DEVBASE_ROOT=${DEVBASE_ROOT}"
    # shellcheck disable=SC2153 # _DEVBASE_FROM_GIT set during bootstrap
    show_progress info "_DEVBASE_FROM_GIT=${_DEVBASE_FROM_GIT}"
    if require_env _DEVBASE_ENV_FILE; then
      show_progress info "_DEVBASE_ENV_FILE=${_DEVBASE_ENV_FILE}"
    fi
    # shellcheck disable=SC2153 # _DEVBASE_ENV set by detect_environment() during bootstrap
    show_progress info "_DEVBASE_ENV=${_DEVBASE_ENV}"
    if [[ -n "${DEVBASE_PROXY_HOST}" && -n "${DEVBASE_PROXY_PORT}" ]]; then
      show_progress info "Proxy configured: ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
    fi
  fi
}

# Brief: Main installation orchestration function
# Params: None
# Uses: DEVBASE_COLORS, rotate_backup_directories, validate_environment, validate_source_repository, setup_installation_paths, run_preflight_checks, collect_user_configuration, display_configuration_summary, prepare_system, perform_installation, write_installation_summary, show_completion_message, handle_wsl_restart (globals/functions)
# Returns: 0 always
# Side-effects: Orchestrates entire DevBase installation process
main() {
  run_preflight_phase || return 1
  run_configuration_phase || return 1
  run_installation_phase || return 1
  run_finalize_phase
  return 0
}

# Custom hook system for organization-specific scripts
run_custom_hook() {
  local hook_name="$1"

  validate_not_empty "$hook_name" "Hook name" || return 1

  # Check if custom hooks directory is configured
  local hooks_dir
  hooks_dir=$(get_custom_hooks_dir)
  if [[ -z "$hooks_dir" || ! -d "$hooks_dir" ]]; then
    return 0 # No custom hooks directory configured
  fi

  local hook_file="${hooks_dir}/${hook_name}.sh"

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
