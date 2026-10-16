#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Migration scripts for DevBase upgrades
# Handles cleanup of legacy files and configuration changes between versions

# Brief: Remove legacy package files replaced by unified packages.yaml
# Context: Prior to unified package management, packages were defined in separate files.
#          These are now consolidated into packages.yaml and the old files are orphaned.
# Returns: 0 always (cleanup is best-effort)
migrate_legacy_package_files() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/devbase"
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

# Brief: Remove legacy fish mise hook pointing to /usr/bin/mise
# Context: apt-installed mise adds fish hook scripts that hardcode /usr/bin/mise
# Returns: 0 always (cleanup is best-effort)
migrate_mise_fish_hook() {
  local removed=0
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local fish_files=(
    "$config_home/fish/functions/fish_command_not_found.fish"
    "$config_home/fish/conf.d/mise.fish"
  )

  for file in "${fish_files[@]}"; do
    if [[ -f "$file" ]] && grep -q "/usr/bin/mise" "$file" 2>/dev/null; then
      rm -f "$file"
      ((removed++))
      if declare -f show_progress &>/dev/null; then
        show_progress info "Removed legacy fish mise hook: ${file}"
      fi
    fi
  done

  if [[ $removed -gt 0 ]] && declare -f show_progress &>/dev/null; then
    show_progress success "Cleaned up legacy fish mise hooks"
    show_progress warning "Restart fish to reload shell hooks"
    if declare -f tui_printf &>/dev/null && [[ -n "${DEVBASE_COLORS[BLINK_SLOW]:-}" ]]; then
      tui_printf "  %b%bRestart fish to reload shell hooks%b\n" \
        "${DEVBASE_COLORS[BOLD_YELLOW]}" \
        "${DEVBASE_COLORS[BLINK_SLOW]}" \
        "${DEVBASE_COLORS[NC]}"
    fi
  fi

  return 0
}

# Brief: Remove legacy pre-push signature hook from active hooks directory
# Context: Signature enforcement moved to post-commit validation; old hook should be removed on update
# Returns: 0 always (cleanup is best-effort)
migrate_git_signature_hook() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local hook_path="${config_dir}/git/git-hooks/pre-push.d/01-verify-signatures.sh"

  if [[ -f "$hook_path" ]]; then
    rm -f "$hook_path"
    rmdir "$(dirname "$hook_path")" 2>/dev/null || true
    if declare -f show_progress &>/dev/null; then
      show_progress info "Removed legacy pre-push signature hook"
    fi
  fi

  return 0
}

# Brief: Remove stale deployed hooks-templates directory
# Context: hooks-templates/ was previously deployed as a dotfile but is only used as a
#          repo source by configure_git_hooks(). It is now excluded from dotfiles deployment;
#          this migration cleans up existing installs that still have the deployed copy.
# Returns: 0 always (cleanup is best-effort)
migrate_deployed_hooks_templates() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local deployed_templates="${config_dir}/git/hooks-templates"

  if [[ -d "$deployed_templates" ]]; then
    safe_rm_rf "$config_dir" "$deployed_templates"
    if declare -f show_progress &>/dev/null; then
      show_progress info "Removed stale deployed hooks-templates directory"
    fi
  fi

  return 0
}

# Brief: Preserve legacy deployed vscode settings directory
# Context: Older installations may still have data in ~/.config/vscode/ and external
#          tooling can still reference it. Removing it during update risks deleting
#          user-managed state or breaking organization-specific workflows.
# Returns: 0 always
migrate_deployed_vscode_settings() {
  return 0
}

# Runs from _pkg_apt_update, before APT reads the obsolete source. Only remove
# dedicated Fish release-4 source files; a shared file needs manual cleanup.
# The optional APT directory is used by fixture tests, never the installed host.
migrate_fish_ppa() (
  local apt_dir="${1:-/etc/apt}" file rc backup_file path staged=''
  trap '[[ -z "$staged" ]] || rm -f -- "$staged"' EXIT
  for file in "$apt_dir/sources.list" "$apt_dir/sources.list.d/"*.list "$apt_dir/sources.list.d/"*.sources; do
    [[ -f "$file" ]] || continue
    rc=0
    awk -v format="${file##*.}" '
      function inspect(value,    words, n, i) {
        n = split(value, words, /[[:blank:]]+/)
        for (i = 1; i <= n; i++) {
          if (words[i] == "") continue
          if (words[i] ~ /^https?:\/\/ppa\.(launchpadcontent\.net|launchpad\.net)\/fish-shell\/release-4\/ubuntu\/?$/)
            fish = 1
          else
            other = 1
        }
      }
      /^[[:blank:]]*#/ { next }
      /^[[:blank:]]*$/ { in_uris = 0; next }
      format == "sources" {
        if (/^[^[:blank:]#][^:]*:/) {
          in_uris = (tolower($0) ~ /^uris:/)
          if (in_uris) {
            value = $0
            sub(/^[^:]*:[[:blank:]]*/, "", value)
            inspect(value)
          }
        } else if (in_uris && /^[[:blank:]]/) {
          inspect($0)
        }
        next
      }
      /^[[:blank:]]*deb(-src)?[[:blank:]]/ {
        value = $0
        sub(/^[[:blank:]]*deb(-src)?[[:blank:]]+/, "", value)
        sub(/^\[[^]]*\][[:blank:]]*/, "", value)
        split(value, words, /[[:blank:]]+/)
        inspect(words[1])
        next
      }
      { other = 1 }
      END { exit fish ? (other ? 2 : 0) : 3 }
    ' "$file" || rc=$?
    [[ "$rc" != 3 ]] || continue
    if [[ "$rc" == 2 ]]; then
      show_progress error "Fish PPA is in a shared APT source; remove that entry manually: $file"
      return 1
    fi
    [[ "$rc" == 0 ]] || return 1
    if [[ -L "$apt_dir" || -L "$(dirname "$file")" || -L "$file" ]]; then
      show_progress error "Refusing linked Fish PPA source: $file"
      return 1
    fi
    validate_var_set DEVBASE_BACKUP_DIR || return 1
    backup_file="${DEVBASE_BACKUP_DIR}/apt/${file#"$apt_dir"/}"
    for path in "$DEVBASE_BACKUP_DIR" "$DEVBASE_BACKUP_DIR/apt" "$(dirname "$backup_file")" "$backup_file"; do
      if [[ -L "$path" ]]; then
        show_progress error "Refusing linked Fish PPA backup: $path"
        return 1
      fi
    done
    [[ ! -e "$backup_file" || -f "$backup_file" ]] || return 1
    mkdir -p "$(dirname "$backup_file")" || return 1
    staged=$(mktemp "${backup_file}.XXXXXX") || return 1
    cp -pT -- "$file" "$staged" || return 1
    chmod 600 "$staged" || return 1
    mv -T --backup=numbered -- "$staged" "$backup_file" || return 1
    [[ ! -L "$file" ]] && cmp -s "$file" "$backup_file" || return 1
    sudo rm -- "$file" || return 1
    show_progress success "Removed legacy Fish PPA source (backup: $backup_file)"
  done
)

# Brief: Run all migrations
# Context: Called during setup.sh to ensure clean state
run_migrations() {
  migrate_legacy_package_files
  migrate_mise_yq_backend
  migrate_mise_fish_hook
  migrate_git_signature_hook
  migrate_deployed_hooks_templates
  migrate_deployed_vscode_settings
}
