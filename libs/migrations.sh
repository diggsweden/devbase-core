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

# Brief: Remove legacy mise yq install (non-aqua backend)
# Context: Devbase now pins yq via aqua:mikefarah/yq; remove old mise yq to avoid duplicates
# Returns: 0 always (cleanup is best-effort)
migrate_mise_yq_backend() {
  if ! command -v mise &>/dev/null; then
    return 0
  fi

  if mise list --installed yq >/dev/null 2>&1; then
    if mise uninstall yq >/dev/null 2>&1; then
      if declare -f show_progress &>/dev/null; then
        show_progress info "Removed legacy mise yq (non-aqua backend)"
      fi
    fi
  fi
  return 0
}

# Brief: Run all migrations
# Context: Called during setup.sh to ensure clean state
run_migrations() {
  migrate_legacy_package_files
  migrate_mise_yq_backend
}
