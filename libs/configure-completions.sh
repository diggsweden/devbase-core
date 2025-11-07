#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Configure Fish shell completions for various tools
# Params: None
# Uses: XDG_CONFIG_HOME (global)
# Returns: 0 always
# Side-effects: Generates completion files for installed tools
configure_fish_completions() {
  command -v fish &>/dev/null || return 0

  show_progress info "Setting up shell completions..."

  local completions_set=0
  local tools_configured=()

  local tools_with_completions=(
    "kubectl"
    "helm"
    "terraform"
    "podman"
    "mise"
  )

  for tool in "${tools_with_completions[@]}"; do
    if command -v "$tool" &>/dev/null; then
      configure_single_fish_completion "$tool"
      completions_set=$((completions_set + 1))
      tools_configured+=("$tool")
    fi
  done

  if [[ $completions_set -gt 0 ]]; then
    local msg="Shell completions configured ($completions_set tools: ${tools_configured[*]})"
    show_progress success "$msg"
  fi

  return 0
}

# Brief: Generate Fish completion file for a single tool
# Params: $1 - tool name
# Uses: XDG_CONFIG_HOME (global)
# Returns: 0 on success, 1 on failure
# Side-effects: Creates completion file
configure_single_fish_completion() {
  local tool="$1"
  local completion_dir="${XDG_CONFIG_HOME}/fish/completions"

  validate_not_empty "$tool" "tool name" || return 1

  case "$tool" in
  kubectl)
    kubectl completion fish >"${completion_dir}/kubectl.fish" 2>/dev/null || return
    ;;
  helm)
    helm completion fish >"${completion_dir}/helm.fish" 2>/dev/null || return
    ;;
  terraform)
    terraform -install-autocomplete &>/dev/null || return
    ;;
  podman)
    podman completion fish >"${completion_dir}/podman.fish" 2>/dev/null || return
    ;;
  mise)
    run_mise_from_home_dir completion fish >"${completion_dir}/mise.fish" 2>/dev/null || return
    ;;
  esac

  return 0
}

# Brief: Configure Bash completions (placeholder)
# Params: None
# Returns: 0 always
# Side-effects: None (not yet implemented)
configure_bash_completions() {
  return 0
}

# Brief: Configure Zsh completions (placeholder)
# Params: None
# Returns: 0 always
# Side-effects: None (not yet implemented)
configure_zsh_completions() {
  return 0
}

# Brief: Configure shell completions for all shells (main entry point)
# Params: None
# Returns: 0 always
# Side-effects: Configures completions for fish, bash, zsh
configure_completions() {
  configure_fish_completions
  configure_bash_completions
  configure_zsh_completions

  return 0
}
