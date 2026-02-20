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

# Brief: Remove legacy fish mise hook pointing to /usr/bin/mise
# Context: apt-installed mise adds fish hook scripts that hardcode /usr/bin/mise
# Returns: 0 always (cleanup is best-effort)
migrate_mise_fish_hook() {
  local removed=0
  local fish_files=(
    "$HOME/.config/fish/functions/fish_command_not_found.fish"
    "$HOME/.config/fish/conf.d/mise.fish"
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
# Context: Signature enforcement moved to conform; old hook should be removed on update
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

# Brief: Remove stale deployed vscode settings directory
# Context: VS Code settings.json was previously deployed as a dotfile to ~/.config/vscode/
#          but is now managed inline by configure_vscode_settings(). The deployed copy was
#          never read by VS Code itself and is just litter.
# Returns: 0 always (cleanup is best-effort)
migrate_deployed_vscode_settings() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local deployed_vscode="${config_dir}/vscode"

  if [[ -d "$deployed_vscode" ]]; then
    safe_rm_rf "$config_dir" "$deployed_vscode"
    if declare -f show_progress &>/dev/null; then
      show_progress info "Removed stale deployed vscode settings directory"
    fi
  fi

  return 0
}

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
