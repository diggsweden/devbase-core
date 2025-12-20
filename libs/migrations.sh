#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Migration scripts for DevBase upgrades
# Handles cleanup of legacy files and configuration changes between versions

set -uo pipefail

# Brief: Remove legacy package files replaced by unified packages.yaml
# Context: Prior to unified package management, packages were defined in separate files.
#          These are now consolidated into packages.yaml and the old files are orphaned.
# Returns: 0 always (cleanup is best-effort)
migrate_legacy_package_files() {
  local config_dir="${HOME}/.config/devbase"
  local removed=0

  local legacy_files=(
    "apt-packages.txt"
    "snap-packages.txt"
    "custom-tools.yaml"
    "vscode-extensions.yaml"
  )

  for file in "${legacy_files[@]}"; do
    local filepath="${config_dir}/${file}"
    if [[ -f "$filepath" ]]; then
      rm -f "$filepath"
      ((removed++))
      if declare -f show_progress &>/dev/null; then
        show_progress info "Removed legacy file: ${file}"
      fi
    fi
  done

  if [[ $removed -gt 0 ]] && declare -f show_progress &>/dev/null; then
    show_progress success "Cleaned up ${removed} legacy package file(s)"
  fi

  return 0
}

# Brief: Run all migrations
# Context: Called during setup.sh to ensure clean state
run_migrations() {
  migrate_legacy_package_files
}
