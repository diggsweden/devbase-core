#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Brief: Central message catalog for shared UI strings
# Params: $1 - message key
# Returns: Message string
ui_message() {
  case "$1" in
  welcome_title)
    echo "DevBase Core Installation"
    ;;
  welcome_subtitle)
    echo "Development environment setup wizard"
    ;;
  welcome_hints)
    echo "j/k navigate  SPACE toggle  ENTER select  Ctrl+C cancel"
    ;;
  welcome_init)
    echo "Initializing..."
    ;;
  system_info_title)
    echo "System Information"
    ;;
  system_info_loading)
    echo "Loading configuration..."
    ;;
  dry_run_bootstrap_skip)
    echo "Dry run mode: skipping installer modifications"
    ;;
  dry_run_install_skip)
    echo "Dry run enabled - skipping installation"
    ;;
  dry_run_plan_header)
    echo "Dry run plan:"
    ;;
  dry_run_plan_preflight)
    echo "Preflight checks"
    ;;
  dry_run_plan_configuration)
    echo "Configuration prompts"
    ;;
  dry_run_plan_installation)
    echo "Installation steps"
    ;;
  dry_run_plan_finalize)
    echo "Finalize steps"
    ;;
  dry_run_plan_actions)
    echo "Actions"
    ;;
  dry_run_plan_packages)
    echo "Packages"
    ;;
  *)
    echo "$1"
    ;;
  esac
}
