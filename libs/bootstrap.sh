#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

show_welcome_banner() {
  local devbase_version
  local git_sha

  read -r devbase_version git_sha <<<"$(resolve_devbase_version)"

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    echo
    gum style \
      --foreground 212 \
      --border double \
      --border-foreground 212 \
      --padding "1 4" \
      --margin "1 0" \
      --align center \
      "DevBase Core Installation" \
      "" \
      "Version: $devbase_version ($git_sha)" \
      "Started: $(date +"%H:%M:%S")"
    echo
    gum style --foreground 240 --align center \
      "Development environment setup wizard"
    gum style --foreground 240 \
      "j/k navigate  SPACE toggle  ENTER select  Ctrl+C cancel"
    echo
  else
    # Whiptail mode (default) - show welcome infobox
    clear
    whiptail --backtitle "$WT_BACKTITLE" --title "DevBase Core Installation" \
      --infobox "Version: $devbase_version ($git_sha)\nStarted: $(date +"%H:%M:%S")\n\nInitializing..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
  fi
}

show_os_info() {
  local os_name env_type install_type
  os_name=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
  env_type=$([[ "${_DEVBASE_ENV:-}" == "wsl-ubuntu" ]] && echo "WSL" || echo "Native Linux")
  install_type=$([[ "${_DEVBASE_FROM_GIT:-}" == "true" ]] && echo "Git repository" || echo "Downloaded")

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum style --foreground 240 "System Information"
    echo "  OS:           $os_name"
    echo "  Environment:  $env_type"
    echo "  Installation: $install_type"
    echo "  User:         $USER"
    echo "  Home:         $HOME"
    echo
  else
    # Whiptail mode - show system info infobox
    whiptail --backtitle "$WT_BACKTITLE" --title "System Information" \
      --infobox "OS: $os_name\nEnvironment: $env_type\nUser: $USER\n\nLoading configuration..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
    sleep 1
  fi
}

show_repository_info() {
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    # Silent in whiptail mode - info shown in whiptail dialogs
    return 0
  fi
  echo "  Running from: $DEVBASE_ROOT"
  echo
}

# Brief: Bootstrap installation prerequisites and UI
# Params: None
# Uses: detect_environment, find_custom_directory, load_environment_configuration,
#       configure_proxy_settings, install_certificates, select_tui_mode,
#       show_welcome_banner, show_os_info, check_required_tools,
#       show_repository_info, test_generic_network_connectivity,
#       validate_custom_config, run_pre_install_hook, set_default_values
# Returns: 0 on success
# Side-effects: Configures env, UI, and validations before install
run_bootstrap() {
  # Minimal pre-TUI setup: detect environment and configure network
  detect_environment || return 1
  find_custom_directory || return 1
  load_environment_configuration || return 1
  configure_proxy_settings || return 1

  if [[ "${DEVBASE_DRY_RUN}" == "true" ]]; then
    show_progress info "Dry run mode: skipping installer modifications"
    return 0
  fi

  # Install certificates before any downloads (gum/mise) to avoid TLS issues
  install_certificates || return 1

  # Bootstrap TUI early (needs network for gum download)
  # This enables gum/whiptail for all subsequent UI
  show_progress info "Preparing installer UI..."
  select_tui_mode || return 1

  # Now show welcome and run checks using TUI
  show_welcome_banner
  show_os_info
  check_required_tools || return 1
  show_repository_info

  test_generic_network_connectivity
  validate_custom_config
  run_pre_install_hook
  set_default_values

  return 0
}

export -f run_bootstrap
