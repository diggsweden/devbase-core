#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

run_preflight_phase() {
  set_default_values
  init_install_context
  rotate_backup_directories
  validate_environment
  validate_source_repository
  setup_installation_paths

  # Run all pre-flight checks (Ubuntu version, disk space, paths, GitHub token)
  # Note: Sudo access is acquired in run_preflight_checks
  tui_blank_line
  run_preflight_checks || return 1
}

run_configuration_phase() {
  bootstrap_for_configuration || return 1
  collect_user_configuration || return 1
  display_configuration_summary || return 1
}

run_installation_phase() {
  # Start persistent progress display for whiptail mode
  # This keeps a gauge on screen throughout installation to prevent terminal flicker
  start_installation_progress

  show_phase "Preparing system..."
  if ! prepare_system; then
    stop_installation_progress
    return 1
  fi

  if ! perform_installation; then
    stop_installation_progress
    return 1
  fi

  if ! write_installation_summary; then
    stop_installation_progress
    return 1
  fi

  # Stop persistent progress display before showing completion
  stop_installation_progress
}

run_finalize_phase() {
  tui_blank_line
  show_completion_message
  show_installation_warnings
  configure_fonts_post_install
  handle_wsl_restart
}
