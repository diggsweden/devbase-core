#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
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

    # DEVBASE_SHELLS_FILE lets the tests exercise the registration branch
    # without consulting the host's /etc/shells.
    local shells_file="${DEVBASE_SHELLS_FILE:-/etc/shells}"
    if ! grep -q "$fish_path" "$shells_file" 2>/dev/null; then
      printf "%s\n" "$fish_path" | sudo tee -a "$shells_file" &>/dev/null
    fi

    # The marker line must stay unchanged: append_bashrc_once inserts
    # organization blocks before it.
    local marker='# Launch Fish for interactive sessions (added by devbase)'
    local legacy_block="${marker}
if [[ \$- == *i* ]] && command -v fish &>/dev/null; then
    exec fish
fi"
    local handoff_block="${marker}
# Skipped when the parent is Fish, so running \`bash\` from Fish stays in Bash.
if [[ \$- == *i* ]] && [[ \"\$(cat /proc/\$PPID/comm 2>/dev/null)\" != fish ]] &&
    command -v fish &>/dev/null; then
    if shopt -q login_shell; then
        exec fish --login
    fi
    exec fish
fi"

    if ! grep -qF "$marker" "${HOME}/.bashrc" 2>/dev/null; then
      printf '\n%s\n' "$handoff_block" >>"${HOME}/.bashrc"
    else
      # Upgrade the handoff written by earlier releases in place.
      local content
      content=$(
        cat "${HOME}/.bashrc"
        printf x
      ) || return 1
      content=${content%x}
      if [[ "$content" == *"$legacy_block"* ]]; then
        printf '%s' "${content/"$legacy_block"/"$handoff_block"}" >"${HOME}/.bashrc"
      fi
    fi
    show_progress success "Fish shell configured (interactive mode)"
  else
    show_progress warning "Fish shell not found - skipping"
  fi
  return 0
}
