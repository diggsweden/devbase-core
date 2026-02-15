#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

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
  require_env DEVBASE_ROOT DEVBASE_LIBS || return 1

  init_bootstrap_context

  # Minimal pre-TUI setup: detect environment and configure network
  detect_environment || return 1
  find_custom_directory || return 1
  load_environment_configuration || return 1
  apply_environment_settings || return 1
  configure_proxy_settings || return 1

  if [[ "${DEVBASE_DRY_RUN}" == "true" ]]; then
    show_progress info "$(ui_message dry_run_bootstrap_skip)"
    return 0
  fi

  # Install certificates before any downloads (gum/mise) to avoid TLS issues
  install_certificates || return 1

  # Bootstrap TUI early (needs network for gum download)
  # This enables gum/whiptail for all subsequent UI
  show_progress info "Preparing installer UI..."
  select_tui_mode || return 1

  # Now show welcome and run checks using TUI
  local devbase_version
  local devbase_sha
  read -r devbase_version devbase_sha <<<"$(resolve_devbase_version)"
  export DEVBASE_VERSION="$devbase_version"
  export DEVBASE_VERSION_SHA="$devbase_sha"

  show_welcome_banner
  show_os_info
  check_required_tools || return 1
  show_repository_info

  test_generic_network_connectivity
  validate_custom_config || return 1
  run_pre_install_hook

  return 0
}

export -f run_bootstrap
