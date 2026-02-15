#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

declare -Ag INSTALL_CONTEXT=()
declare -ag INSTALL_WARNINGS=()

init_install_context() {
  INSTALL_CONTEXT=()
  INSTALL_WARNINGS=()
  INSTALL_CONTEXT[custom_hooks_dir]="${_DEVBASE_CUSTOM_HOOKS:-}"
  INSTALL_CONTEXT[env]="${_DEVBASE_ENV:-}"
}

get_custom_hooks_dir() {
  printf "%s" "${INSTALL_CONTEXT[custom_hooks_dir]:-${_DEVBASE_CUSTOM_HOOKS:-}}"
}

add_install_warning() {
  local message="$1"
  INSTALL_WARNINGS+=("$message")
  show_progress warning "$message"
}

show_installation_warnings() {
  if [[ ${#INSTALL_WARNINGS[@]} -eq 0 ]]; then
    return 0
  fi

  show_progress warning "Installation completed with warnings:"
  for warning in "${INSTALL_WARNINGS[@]}"; do
    show_progress warning "  - $warning"
  done

  return 0
}

export -f init_install_context
export -f get_custom_hooks_dir
export -f add_install_warning
export -f show_installation_warnings
