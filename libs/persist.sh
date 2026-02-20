#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Brief: Persist devbase repos to user data directory for update support
# Params: None
# Uses: DEVBASE_ROOT, DEVBASE_CUSTOM_DIR, _DEVBASE_FROM_GIT, XDG_DATA_HOME (globals)
# Returns: 0 on success
# Side-effects: Clones/updates repos to ~/.local/share/devbase/{core,custom}
persist_devbase_repos() {
  require_env XDG_DATA_HOME DEVBASE_ROOT _DEVBASE_FROM_GIT || return 1

  local core_dest="$XDG_DATA_HOME/devbase/core"
  local custom_dest="$XDG_DATA_HOME/devbase/custom"

  mkdir -p "$(dirname "$core_dest")"

  # Persist core repo
  if [[ "$_DEVBASE_FROM_GIT" == "true" ]]; then
    local current_remote
    local current_tag
    local core_ref
    current_remote=$(git -C "$DEVBASE_ROOT" remote get-url origin 2>/dev/null || echo "")
    current_tag=$(git -C "$DEVBASE_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "main")
    core_ref="${DEVBASE_CORE_REF:-$current_tag}"

    if [[ -z "$current_remote" ]]; then
      show_progress warning "Could not determine core remote URL - skipping repo persistence"
      return 1
    fi

    if [[ ! -d "$core_dest/.git" ]]; then
      show_progress step "Cloning devbase-core to persistent location..."
      if git clone --depth 1 --branch "$core_ref" "$current_remote" "$core_dest" 2>/dev/null; then
        show_progress success "Core repo cloned to $core_dest"
      else
        # Fallback: clone without branch (tag might not exist on fresh clone)
        git clone --depth 1 "$current_remote" "$core_dest"
        git -C "$core_dest" fetch --depth 1 --tags --quiet

        if [[ -n "${DEVBASE_CORE_REF:-}" ]]; then
          if git -C "$core_dest" fetch --depth 1 origin "+refs/heads/*:refs/remotes/origin/*" --quiet 2>/dev/null &&
            git -C "$core_dest" checkout "origin/$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          elif git -C "$core_dest" fetch --depth 1 origin "+refs/tags/$core_ref:refs/tags/$core_ref" --quiet 2>/dev/null &&
            git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          else
            show_progress warning "Could not checkout core ref: $core_ref"
          fi
        else
          if git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          else
            show_progress success "Core repo cloned to $core_dest"
          fi
        fi
      fi
    else
      # Already exists - update to current tag or requested ref
      show_progress step "Updating persistent core repo..."
      if [[ -n "${DEVBASE_CORE_REF:-}" ]]; then
        if git -C "$core_dest" fetch --depth 1 origin "+refs/heads/*:refs/remotes/origin/*" --quiet 2>/dev/null &&
          git -C "$core_dest" checkout "origin/$core_ref" --quiet 2>/dev/null; then
          show_progress success "Core repo updated at $core_dest"
        elif git -C "$core_dest" fetch --depth 1 origin "+refs/tags/$core_ref:refs/tags/$core_ref" --quiet 2>/dev/null &&
          git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
          show_progress success "Core repo updated at $core_dest"
        else
          show_progress warning "Could not checkout core ref: $core_ref"
        fi
      else
        if git -C "$core_dest" fetch --depth 1 origin "$core_ref" --quiet 2>/dev/null ||
          git -C "$core_dest" fetch --depth 1 --tags --quiet; then
          if git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo updated at $core_dest"
          else
            show_progress success "Core repo updated at $core_dest"
          fi
        fi
      fi
    fi
  else
    show_progress info "Not running from git clone - skipping core repo persistence"
  fi

  # Persist custom config repo (if it's a git repo)
  if [[ -n "${DEVBASE_CUSTOM_DIR:-}" ]] && git -C "$DEVBASE_CUSTOM_DIR" rev-parse --git-dir &>/dev/null; then
    local custom_remote
    custom_remote=$(git -C "$DEVBASE_CUSTOM_DIR" remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$custom_remote" ]]; then
      if [[ ! -d "$custom_dest/.git" ]]; then
        show_progress step "Cloning custom config to persistent location..."
        git clone --depth 1 "$custom_remote" "$custom_dest"
        show_progress success "Custom config cloned to $custom_dest"
      else
        show_progress step "Updating persistent custom config..."
        git -C "$custom_dest" fetch --depth 1 --quiet
        git -C "$custom_dest" reset --hard origin/HEAD --quiet 2>/dev/null ||
          git -C "$custom_dest" reset --hard origin/main --quiet 2>/dev/null || true
        show_progress success "Custom config updated at $custom_dest"
      fi
    fi
  fi

  return 0
}

export -f persist_devbase_repos
