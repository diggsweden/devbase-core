#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Configure Fish shell as interactive default shell
# Params: None
# Uses: HOME (global)
# Returns: 0 always
# Side-effects: Adds fish to /etc/shells, modifies .bashrc
configure_fish_interactive() {
  validate_var_set "HOME" || return 1

  show_progress info "Configuring Fish shell..."

  if command -v fish &>/dev/null; then
    local fish_path
    fish_path=$(command -v fish)

    if ! grep -q "$fish_path" /etc/shells; then
      printf "%s\n" "$fish_path" | sudo tee -a /etc/shells &>/dev/null
    fi

    if ! grep -q "Launch Fish for interactive sessions (added by devbase)" "${HOME}/.bashrc"; then
      cat >>"${HOME}/.bashrc" <<'EOF'

# Launch Fish for interactive sessions (added by devbase)
if [[ $- == *i* ]] && command -v fish &>/dev/null; then
    exec fish
fi
EOF
    fi
    show_progress success "Fish shell configured (interactive mode)"
  else
    show_progress warning "Fish shell not found - skipping"
  fi
  return 0
}
