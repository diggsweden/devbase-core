#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2154,SC2164,SC2268
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
#
# Shared test helper functions for BATS tests
#
# Shellcheck disabled:
#   SC2016 - Expressions don't expand in single quotes (intentional in mock scripts)
#   SC2154 - Variables like $output/$stderr are set by bats, not this script
#   SC2164 - cd without || exit is fine in test helpers (bats handles failures)
#   SC2268 - x-prefix in comparisons is a common bats pattern for empty checks

# =============================================================================
# Common Setup/Teardown Helpers
# =============================================================================

# Standard test setup - creates temp dir and sets DEVBASE_ROOT
# Usage: common_setup
common_setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  export DEVBASE_TUI_MODE='none' # Disable whiptail for predictable test output
}

# Standard test teardown - cleans up temp dir safely
# Usage: common_teardown
common_teardown() {
  safe_temp_del "$TEST_DIR"
}

# Setup with isolated HOME environment
# Usage: common_setup_isolated
common_setup_isolated() {
  common_setup
  setup_isolated_home
}

# =============================================================================
# Safe Temp Directory Cleanup
# =============================================================================

# Safely delete a temp directory, handling git's write-protected objects
# This wraps temp_del but makes files writable first to avoid interactive prompts
# SAFETY: Only deletes directories under /tmp or $BATS_TMPDIR
# Usage: safe_temp_del <path>
safe_temp_del() {
  local path="$1"
  [[ -z "$path" ]] && return 0
  [[ ! -d "$path" ]] && return 0

  # Resolve to absolute path
  local abs_path
  abs_path="$(cd "$path" 2>/dev/null && pwd)" || return 0

  # SAFETY: Only allow deletion in /tmp or BATS_TMPDIR
  local allowed_base="${BATS_TMPDIR:-/tmp}"
  if [[ "$abs_path" != /tmp/* && "$abs_path" != "$allowed_base"/* ]]; then
    echo "ERROR: safe_temp_del refuses to delete '$abs_path' - not in /tmp or BATS_TMPDIR" >&2
    return 1
  fi

  # Extra safety: refuse to delete if path is too short (e.g., /tmp itself)
  if [[ "${#abs_path}" -lt 10 ]]; then
    echo "ERROR: safe_temp_del refuses to delete '$abs_path' - path too short" >&2
    return 1
  fi

  # Make all files writable to avoid rm prompting on git objects
  chmod -R u+w "$abs_path" 2>/dev/null || true
  temp_del "$abs_path"
}

# =============================================================================
# Isolated Environment Setup
# =============================================================================

# Setup isolated HOME and XDG directories in TEST_DIR
# Usage: setup_isolated_home
# Sets: HOME, XDG_DATA_HOME, XDG_CONFIG_HOME
setup_isolated_home() {
  export HOME="${TEST_DIR}/home"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_CONFIG_HOME="${HOME}/.config"
  mkdir -p "$HOME"
  mkdir -p "$XDG_DATA_HOME"
  mkdir -p "$XDG_CONFIG_HOME"
}

# =============================================================================
# Common Library Sourcing
# =============================================================================

# Source core UI libraries (colors, validation, ui-helpers)
# Usage: source_core_libs
# Requires: DEVBASE_ROOT to be set
source_core_libs() {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
}

# Source core UI libraries plus check-requirements
# Usage: source_core_libs_with_requirements
# Requires: DEVBASE_ROOT to be set
source_core_libs_with_requirements() {
  source_core_libs
  source "${DEVBASE_ROOT}/libs/check-requirements.sh"
}

# =============================================================================
# Isolated Command Execution
# =============================================================================

# Run a bash command in a clean environment, preserving only essential variables
# Usage: run_isolated <bash_command>
# Example: run_isolated "source lib.sh && my_function"
# Clears: proxy vars, curl opts, WSL vars, and other env pollution
run_isolated() {
  local cmd="$1"
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TERM="${TERM:-xterm}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${DEVBASE_DOT:-}" \
    TEST_DIR="${TEST_DIR:-}" \
    bash -c "$cmd"
}

# Run a bash command simulating WSL environment
# Usage: run_as_wsl <bash_command> [wsl_distro_name]
# Sets WSL_DISTRO_NAME to simulate running in WSL
run_as_wsl() {
  local cmd="$1"
  local distro="${2:-Ubuntu}"
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TERM="${TERM:-xterm}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${DEVBASE_DOT:-}" \
    TEST_DIR="${TEST_DIR:-}" \
    WSL_DISTRO_NAME="$distro" \
    bash -c "$cmd"
}

# Run a bash command simulating WSL environment via WSL_INTEROP
# Usage: run_as_wsl_interop <bash_command>
run_as_wsl_interop() {
  local cmd="$1"
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TERM="${TERM:-xterm}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${DEVBASE_DOT:-}" \
    TEST_DIR="${TEST_DIR:-}" \
    WSL_INTEROP="/run/WSL/some_value" \
    bash -c "$cmd"
}

# Run a bash command with proxy environment configured
# Usage: run_with_proxy <bash_command> [proxy_host] [proxy_port] [extra_path]
run_with_proxy() {
  local cmd="$1"
  local proxy_host="${2:-proxy.example.com}"
  local proxy_port="${3:-8080}"
  local extra_path="${4:-}"
  local use_path="$PATH"
  [[ -n "$extra_path" ]] && use_path="${extra_path}:${PATH}"
  env -i \
    HOME="$HOME" \
    PATH="$use_path" \
    TERM="${TERM:-xterm}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${DEVBASE_DOT:-}" \
    TEST_DIR="${TEST_DIR:-}" \
    DEVBASE_PROXY_HOST="$proxy_host" \
    DEVBASE_PROXY_PORT="$proxy_port" \
    bash -c "$cmd"
}

# =============================================================================
# Git Repository Helpers
# =============================================================================

# Create a mock git repository for testing
# All git config is local to the repo (no host config needed)
# Usage: create_mock_git_repo <repo_dir> [tag] [remote_url]
create_mock_git_repo() {
  local repo_dir="$1"
  local tag="${2:-v1.0.0}"
  local remote="${3:-https://github.com/test/repo.git}"

  # Prevent reading system git config
  export GIT_CONFIG_NOSYSTEM=1

  mkdir -p "$repo_dir"
  git -C "$repo_dir" init --quiet
  # Local config only - doesn't affect host
  git -C "$repo_dir" config user.email "test@test.com"
  git -C "$repo_dir" config user.name "Test"
  git -C "$repo_dir" config commit.gpgsign false
  git -C "$repo_dir" config tag.gpgsign false
  # Make git objects writable so safe_temp_del can clean up
  git -C "$repo_dir" config core.sharedRepository 0644
  touch "$repo_dir/README.md"
  git -C "$repo_dir" add .
  git -C "$repo_dir" commit -m "Initial" --quiet
  # Create annotated tag with message (no editor prompt)
  git -C "$repo_dir" tag -a "$tag" -m "Release $tag"
  git -C "$repo_dir" remote add origin "$remote"
}

# =============================================================================
# Debug Helpers
# =============================================================================

# Standard debug output for failed tests
# Usage: debug_output (call after 'run' command)
debug_output() {
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
}

# =============================================================================
# Mock Helpers
# =============================================================================

# Create repeated stub that always returns the same result
# Usage: stub_repeated <command> <behavior>
stub_repeated() {
  local cmd="$1"
  local behavior="$2"

  mkdir -p "${TEST_DIR}/bin"
  cat >"${TEST_DIR}/bin/${cmd}" <<SCRIPT
#!/usr/bin/env bash
${behavior}
SCRIPT
  chmod +x "${TEST_DIR}/bin/${cmd}"
  export PATH="${TEST_DIR}/bin:${PATH}"
}

# Create a git mock for update testing with configurable behavior
# Usage: create_git_update_mock [options]
#   --core-tag <tag>        Tag to return for ls-remote (default: v1.0.0)
#   --new-core-tag <tag>    Additional newer tag to simulate update available
#   --custom-sha <sha>      SHA to return for origin/HEAD (simulates custom update)
#   --fetch-fails           Make fetch operations fail (offline mode)
#   --log                   Log git calls to ${TEST_DIR}/logs/git.log
# Example: create_git_update_mock --core-tag v1.0.0 --new-core-tag v2.0.0 --log
create_git_update_mock() {
  local core_tag="v1.0.0"
  local new_core_tag=""
  local custom_sha=""
  local fetch_fails="false"
  local log_calls="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --core-tag)
      core_tag="$2"
      shift 2
      ;;
    --new-core-tag)
      new_core_tag="$2"
      shift 2
      ;;
    --custom-sha)
      custom_sha="$2"
      shift 2
      ;;
    --fetch-fails)
      fetch_fails="true"
      shift
      ;;
    --log)
      log_calls="true"
      shift
      ;;
    *) shift ;;
    esac
  done

  mkdir -p "${TEST_DIR}/bin"
  [[ "$log_calls" == "true" ]] && mkdir -p "${TEST_DIR}/logs"

  # Build conditional parts of the script
  local log_line=""
  local fetch_exit="exit 0"
  local new_tag_line=""
  local custom_sha_block=""

  [[ "$log_calls" == "true" ]] && log_line="echo \"\$*\" >> \"${TEST_DIR}/logs/git.log\""
  [[ "$fetch_fails" == "true" ]] && fetch_exit="exit 1"
  [[ -n "$new_core_tag" ]] && new_tag_line="echo \"def456	refs/tags/${new_core_tag}\""
  [[ -n "$custom_sha" ]] && custom_sha_block="echo \"${custom_sha}\"; exit 0"

  cat >"${TEST_DIR}/bin/git" <<SCRIPT
#!/usr/bin/env bash
${log_line}

# Handle fetch
if [[ "\$*" == *"fetch"* ]]; then
  ${fetch_exit}
fi

# Handle ls-remote for tags
if [[ "\$*" == *"ls-remote"* ]]; then
  echo "abc123	refs/tags/${core_tag}"
  ${new_tag_line}
  exit 0
fi

# Handle origin SHA for custom config
if [[ "\$*" == *"rev-parse --short origin/HEAD"* ]] || [[ "\$*" == *"rev-parse --short origin/main"* ]]; then
  ${custom_sha_block:-exec /usr/bin/git "\$@"}
fi

# Handle checkout/stash/reset (for update operations)
if [[ "\$*" == *"checkout"* ]] || [[ "\$*" == *"stash"* ]] || [[ "\$*" == *"reset"* ]]; then
  exit 0
fi

# Pass through to real git
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  export PATH="${TEST_DIR}/bin:${PATH}"
}
