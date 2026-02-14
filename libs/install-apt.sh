#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Legacy APT package loading (backward compatibility)
# All package operations are now handled by pkg/pkg-manager.sh + pkg/pkg-apt.sh

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

if [[ -z "${DEVBASE_DOT:-}" ]]; then
  echo "ERROR: DEVBASE_DOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Read APT package list from packages.yaml (backward compatibility)
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_SELECTED_PACKS, get_apt_packages (globals/functions)
# Returns: 0 on success, 1 if no packages found
# Outputs: Array of package names to global APT_PACKAGES_ALL
# Side-effects: Populates APT_PACKAGES_ALL array, filters by tags
# Deprecated: Use load_system_packages() from pkg/pkg-manager.sh instead
load_apt_packages() {
  # Source parser if not already loaded
  if ! declare -f get_apt_packages &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser"
  fi

  _setup_package_yaml_env || return 1

  # Get packages from parser
  local packages=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && packages+=("$pkg")
  done < <(get_apt_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress error "No APT packages found in configuration"
    return 1
  fi

  # Export as readonly array
  readonly APT_PACKAGES_ALL=("${packages[@]}")

  return 0
}
