#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

#TODO: a long function should and could we split it a bit?
# Brief: Configure git hooks from templates and custom sources
# Params: None
# Uses: DEVBASE_ENABLE_GIT_HOOKS, DEVBASE_DOT, DEVBASE_CUSTOM_DIR, XDG_CONFIG_HOME, DEVBASE_BACKUP_DIR (globals)
# Returns: 0 always
# Side-effects: Backs up existing hooks, copies templates, sets executable permissions
configure_git_hooks() {
  validate_var_set "XDG_CONFIG_HOME" || return 1
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "DEVBASE_BACKUP_DIR" || return 1

  [[ "$DEVBASE_ENABLE_GIT_HOOKS" != "true" ]] && {
    show_progress info "Git hooks disabled (skipping)"
    return 0
  }

  show_progress info "Configuring git hooks..."

  local hooks_dir="${XDG_CONFIG_HOME}/git/git-hooks"
  # shellcheck disable=SC2153 # DEVBASE_DOT is exported in setup.sh
  local templates_dir="${DEVBASE_DOT}/.config/git/hooks-templates"
  local custom_hooks_dir="${DEVBASE_CUSTOM_DIR}/git-hooks"
  local backup_dir="${DEVBASE_BACKUP_DIR}/git-hooks"

  # Backup existing hooks if directory exists and contains files
  if [[ -d "$hooks_dir" ]] && [[ -n "$(ls -A "$hooks_dir" 2>/dev/null)" ]]; then
    mkdir -p "$backup_dir"
    while IFS= read -r -d '' file; do
      local rel_path="${file#"$hooks_dir"/}"
      local backup_path="$backup_dir/$rel_path"
      mkdir -p "$(dirname "$backup_path")"
      cp --no-dereference "$file" "$backup_path"
    done < <(find "$hooks_dir" -maxdepth 5 -type f -print0)
  fi

  # Create hooks directory structure
  mkdir -p "$hooks_dir"

  # Copy core template hooks
  if [[ -d "$templates_dir" ]]; then
    # Copy dispatchers (main hook files)
    find "$templates_dir" -maxdepth 1 -type f -exec cp {} "$hooks_dir/" \;

    # Copy subdirectories (*.d/ directories with all contents including .sample)
    find "$templates_dir" -maxdepth 1 -type d -name "*.d" -exec cp -r {} "$hooks_dir/" \;
  fi

  # Overlay custom organization hooks if they exist
  if [[ -n "${DEVBASE_CUSTOM_DIR}" ]] && [[ -d "$custom_hooks_dir" ]]; then
    show_progress info "Applying organization-specific git hooks..."
    cp -r "$custom_hooks_dir"/* "$hooks_dir/" || show_progress warning "Failed to copy custom git hooks"
  fi

  # Make hook dispatchers executable
  find "$hooks_dir" -maxdepth 1 -type f ! -name "*.md" ! -name "*.sample" -exec chmod +x {} \; || show_progress warning "Failed to make some git hooks executable"

  # Make .sh files in .d/ directories executable (excluding .sample)
  find "$hooks_dir" -type f -path "*/*.d/*.sh" ! -name "*.sample" -exec chmod +x {} \; || show_progress warning "Failed to make some hook scripts executable"

  # Configure git to use the hooks directory
  git config --global core.hooksPath "$hooks_dir"

  local backed_up=0
  [[ -d "$backup_dir" ]] && backed_up=$(find "$backup_dir" -type f 2>/dev/null | wc -l)

  local msg="Git hooks configured"
  [[ $backed_up -gt 0 ]] && msg="${msg} ($backed_up files backed up)"
  show_progress success "$msg"
  return 0
}
