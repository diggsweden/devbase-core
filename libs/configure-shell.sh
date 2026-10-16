#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Upgrade an unedited legacy handoff without exposing a partial .bashrc.
_upgrade_fish_handoff() (
  local target_file="$1" legacy_block="$2" handoff_block="$3"
  local candidate content
  candidate=$(mktemp "${target_file}.devbase.XXXXXX") || return 1
  trap 'rm -f -- "$candidate"' EXIT
  cp -p -- "$target_file" "$candidate" || return 1
  # The sentinel preserves trailing newlines; a failed read must still fail.
  content=$(
    cat "$candidate" || return 1
    printf x
  ) || return 1
  content=${content%x}
  [[ "$content" == *"$legacy_block"* ]] || return 0

  validate_var_set "DEVBASE_BACKUP_DIR" || return 1
  local backup_dir="${DEVBASE_BACKUP_DIR}/shell"
  [[ ! -L "$backup_dir" ]] || return 1
  mkdir -p "$backup_dir" || return 1
  chmod 700 "$backup_dir" || return 1
  cp -pT --backup=numbered -- "$candidate" "${backup_dir}/bashrc" || return 1
  printf '%s' "${content/"$legacy_block"/"$handoff_block"}" >"$candidate" || return 1
  if [[ -L "$target_file" ]] || ! cmp -s "$target_file" "${backup_dir}/bashrc"; then
    show_progress error ".bashrc changed while preparing the Fish handoff; leaving it unchanged"
    return 1
  fi
  mv -T -- "$candidate" "$target_file"
)

# Brief: Configure Fish shell as interactive default shell
# Params: None
# Uses: HOME, DEVBASE_BACKUP_DIR (globals)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Adds fish to /etc/shells, modifies .bashrc with a backup on migration
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
      printf "%s\n" "$fish_path" | sudo tee -a "$shells_file" &>/dev/null || return 1
    fi

    local bashrc="${HOME}/.bashrc"
    if [[ -L "$bashrc" ]]; then
      show_progress warning "Preserving linked .bashrc; configure the Fish handoff manually"
      return 0
    fi
    if [[ -e "$bashrc" && ! -f "$bashrc" ]]; then
      show_progress error "Cannot configure Fish handoff: .bashrc is not a regular file"
      return 1
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

    if ! grep -qF "$marker" "$bashrc" 2>/dev/null; then
      printf '\n%s\n' "$handoff_block" >>"$bashrc" || return 1
    else
      _upgrade_fish_handoff "$bashrc" "$legacy_block" "$handoff_block" || return 1
    fi
    show_progress success "Fish shell configured (interactive mode)"
  else
    show_progress warning "Fish shell not found - skipping"
  fi
  return 0
}
