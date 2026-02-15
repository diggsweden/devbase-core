#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

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
  detect_environment
  find_custom_directory
  load_environment_configuration
  configure_proxy_settings

  # Install certificates before any downloads (gum/mise) to avoid TLS issues
  install_certificates

  # Bootstrap TUI early (needs network for gum download)
  # This enables gum/whiptail for all subsequent UI
  show_progress info "Preparing installer UI..."
  select_tui_mode

  # Now show welcome and run checks using TUI
  show_welcome_banner
  show_os_info
  check_required_tools
  show_repository_info

  test_generic_network_connectivity
  validate_custom_config
  run_pre_install_hook
  set_default_values

  return 0
}

export -f run_bootstrap
