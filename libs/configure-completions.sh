#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Tools that print a Fish completion script to stdout, with the arguments
# that produce it. Tools whose releases ship no completion files (aqua
# installs) are covered here; `just` prints a loader that defers to the
# binary at completion time. mise is handled separately below.
declare -gA DEVBASE_FISH_COMPLETION_ARGS=(
  [argocd]="completion fish"
  [bat]="--completion fish"
  [buildah]="completion fish"
  [cosign]="completion fish"
  [delta]="--generate-completion fish"
  [fd]="--gen-completions fish"
  [gh]="completion -s fish"
  [gitleaks]="completion fish"
  [glab]="completion -s fish"
  [just]="--completions fish"
  [jwt]="completion fish"
  [k6]="completion fish"
  [k9s]="completion fish"
  [lychee]="--generate complete-fish"
  [kubectl]="completion fish"
  [oc]="completion fish"
  [podman]="completion fish"
  [rg]="--generate complete-fish"
  [rumdl]="completions fish"
  [skopeo]="completion fish"
  ["slsa-verifier"]="completion fish"
  [starship]="completions fish"
  [syft]="completion fish"
  [taplo]="completions fish"
  [tkn]="completion fish"
  ["tree-sitter"]="complete --shell fish"
  [trivy]="completion fish"
  [yq]="shell-completion fish"
  [zellij]="setup --generate-completion fish"
)

# Brief: Locate a tool on PATH or in the mise installs
# Params: $1 - tool name
# Uses: run_mise_from_home_dir (function)
# Returns: 0 and prints the executable path, 1 when the tool is absent
_fish_completion_tool_path() {
  local tool="$1" path
  if path=$(command -v "$tool" 2>/dev/null); then
    printf '%s\n' "$path"
    return 0
  fi
  # The installer shell may not have the mise tool directories on PATH yet.
  path=$(run_mise_from_home_dir which "$tool" 2>/dev/null) && [[ -n "$path" ]] && printf '%s\n' "$path"
}

# Brief: Configure Fish shell completions for installed tools
# Params: None
# Uses: XDG_CONFIG_HOME, DEVBASE_FISH_COMPLETION_ARGS (globals)
# Returns: 0 always
# Side-effects: Generates completion files for installed tools
configure_fish_completions() {
  command -v fish &>/dev/null || return 0

  show_progress info "Setting up shell completions..."

  local tools_configured=()
  local tool
  while IFS= read -r tool; do
    configure_single_fish_completion "$tool" && tools_configured+=("$tool")
  done < <(printf '%s\n' "${!DEVBASE_FISH_COMPLETION_ARGS[@]}" mise | sort)

  if [[ ${#tools_configured[@]} -gt 0 ]]; then
    show_progress success "Shell completions configured (${#tools_configured[@]} tools: ${tools_configured[*]})"
  fi

  return 0
}

# Brief: Generate the Fish completion file for a single tool
# Params: $1 - tool name
# Uses: XDG_CONFIG_HOME, DEVBASE_FISH_COMPLETION_ARGS (globals)
# Returns: 0 on success or unknown tool, 1 when the tool is absent or fails
# Side-effects: Replaces ${XDG_CONFIG_HOME}/fish/completions/<tool>.fish; a
#               tool that prints nothing leaves any existing file untouched
configure_single_fish_completion() {
  local tool="$1"
  local completion_dir="${XDG_CONFIG_HOME}/fish/completions"

  validate_not_empty "$tool" "tool name" || return 1

  local -a command
  local tool_path
  if [[ "$tool" == "mise" ]]; then
    command -v mise &>/dev/null || return 1
    command=(run_mise_from_home_dir completion fish)
  elif [[ -n "${DEVBASE_FISH_COMPLETION_ARGS[$tool]:-}" ]]; then
    tool_path=$(_fish_completion_tool_path "$tool") || return 1
    # shellcheck disable=SC2206 # The table holds whitespace-separated arguments.
    command=("$tool_path" ${DEVBASE_FISH_COMPLETION_ARGS[$tool]})
  else
    return 0
  fi

  mkdir -p "$completion_dir" || return 1
  local staged
  staged=$(mktemp "${completion_dir}/.${tool}.XXXXXX") || return 1
  if ! "${command[@]}" >"$staged" 2>/dev/null || [[ ! -s "$staged" ]]; then
    rm -f -- "$staged"
    return 1
  fi
  mv -f -- "$staged" "${completion_dir}/${tool}.fish"
}

# Brief: Seed the tldr page cache so `tldr <tool>` works from the first shell
# Params: None
# Uses: show_progress (function); honours HTTP(S)_PROXY from the environment
# Returns: 0 when seeded or tldr is absent, 1 when the update failed
# Side-effects: Downloads the tldr pages into the tldr cache directory
seed_tldr_cache() {
  local tldr
  tldr=$(_fish_completion_tool_path tldr) || return 0
  # tlrc refreshes a stale cache itself; only a missing one needs seeding
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/tlrc"
  [[ -d "$cache" && -n "$(ls -A "$cache" 2>/dev/null)" ]] && return 0

  show_progress info "Seeding tldr page cache..."
  if timeout 120 "$tldr" --update --quiet &>/dev/null; then
    show_progress success "tldr page cache seeded"
    return 0
  fi
  return 1
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
