#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for devbase-update fish function

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  mkdir -p "$XDG_DATA_HOME/devbase"
  export DEVBASE_UPDATE_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-update.fish"
}

teardown() {
  common_teardown
}

# Helper to run fish commands with the devbase-update function loaded
run_fish_update() {
  fish -c "source '$DEVBASE_UPDATE_FISH'; $*"
}

@test "snoozed shell startup never invokes the network update check" {
  mkdir -p "$HOME/.local/share/devbase/core/.git" "$HOME/.config/devbase"
  # A snooze written by an earlier `devbase-update --snooze`, 24 hours ahead
  echo $(( $(date +%s) + 86400 )) >"$HOME/.config/devbase/update-snooze"
  # Like a real shell start: nothing pre-sourced, functions autoload from the shipped directory
  run fish --no-config -c "
    set -gx HOME '$HOME'
    set fish_function_path '${DEVBASE_ROOT}/dot/.config/fish/functions' \$fish_function_path
    function devbase-update; echo UNEXPECTED_NETWORK_CHECK; end
    __devbase_update_check
  "
  assert_success
  assert_output ''
}

@test "devbase-update --snooze and the shell-start check agree on the snooze file" {
  mkdir -p "$HOME/.local/share/devbase/core/.git"
  # Two shells, as in real life: one sets the snooze, a fresh one reads it via autoload
  fish --no-config -c "
    set -gx HOME '$HOME'
    set fish_function_path '${DEVBASE_ROOT}/dot/.config/fish/functions' \$fish_function_path
    devbase-update --snooze 24 >/dev/null
  "
  run fish --no-config -c "
    set -gx HOME '$HOME'
    set fish_function_path '${DEVBASE_ROOT}/dot/.config/fish/functions' \$fish_function_path
    __devbase_update_is_snoozed; and echo SNOOZED
  "
  assert_success
  assert_output 'SNOOZED'
}

@test "devbase-update.fish function file exists" {
  assert_file_exists "$DEVBASE_UPDATE_FISH"
}

@test "devbase-update --help shows usage" {
  run run_fish_update "devbase-update --help"
  
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--ref"
  assert_output --partial "--check"
  assert_output --partial "--version"
}

@test "devbase-update --version fails without core repo" {
  run run_fish_update "devbase-update --version"
  
  assert_failure
  assert_output --partial "Core repo not found"
}

@test "devbase-update --version shows version from git repo" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.2.3" "https://github.com/diggsweden/devbase-core.git"
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --version
  "
  
  assert_success
  assert_output --partial "DevBase Version Info"
  assert_output --partial "Tag:    v1.2.3"
  assert_output --partial "https://github.com/diggsweden/devbase-core.git"
}

@test "devbase-update --version shows custom config when present" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.2.3" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/devbase-custom.git"
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --version
  "
  
  assert_success
  assert_output --partial "Core:"
  assert_output --partial "Custom Config:"
  assert_output --partial "https://github.com/myorg/devbase-custom.git"
}

@test "devbase-update --check fails without core repo" {
  run run_fish_update "devbase-update --check"
  
  assert_failure
}

@test "devbase-update --check returns no output when up to date" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Create mock git script
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
# Intercept network operations - return same version (no update)
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  exit 0
fi
# Pass through to real git for local operations
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "
  
  # Should fail (return 1) because no updates available
  assert_failure
  assert_output ""
}

@test "devbase-update --check reports available update" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Create mock git script that returns a newer version
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
# Intercept network operations - return newer version available
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  # Return v2.0.0 as available (newer than v1.0.0)
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
# Pass through to real git for local operations
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "
  
  # Should succeed (return 0) because update is available
  assert_success
  assert_output --partial "v1.0.0"
  assert_output --partial "v2.0.0"
}

@test "devbase-update unknown option shows error" {
  run run_fish_update "devbase-update --invalid-option"
  
  assert_failure
  assert_output --partial "Unknown option"
}

@test "__devbase_update_get_core_info extracts tag sha and remote from git" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v2.0.0" "https://github.com/test/core.git"
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_core_info
    echo \"TAG=\$CORE_TAG\"
    echo \"REMOTE=\$CORE_REMOTE\"
  "
  
  assert_success
  assert_output --partial "TAG=v2.0.0"
  assert_output --partial "REMOTE=https://github.com/test/core.git"
}

@test "__devbase_update_get_custom_info returns empty when no custom repo" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/test/core.git"
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_custom_info
    if test -z \"\$CUSTOM_SHA\"
      echo 'SHA=empty'
    else
      echo \"SHA=\$CUSTOM_SHA\"
    end
    if test -z \"\$CUSTOM_REMOTE\"
      echo 'REMOTE=empty'
    else
      echo \"REMOTE=\$CUSTOM_REMOTE\"
    end
  "
  
  assert_success
  assert_output --partial "SHA=empty"
  assert_output --partial "REMOTE=empty"
}

@test "__devbase_update_get_custom_info extracts sha and remote when custom repo exists" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/test/core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_custom_info
    echo \"REMOTE=\$CUSTOM_REMOTE\"
  "
  
  assert_success
  assert_output --partial "REMOTE=https://github.com/myorg/custom.git"
}

# =============================================================================
# __devbase_update_check.fish (shell startup check)
# =============================================================================

@test "__devbase_update_check skips when core repo does not exist" {
  export DEVBASE_UPDATE_CHECK_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_update_check.fish"
  
  # No core repo created - should silently return
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    source '$DEVBASE_UPDATE_CHECK_FISH'
    __devbase_update_check
  "
  
  assert_success
  assert_output ""
}

@test "__devbase_update_check shows update banner when update available" {
  export DEVBASE_UPDATE_CHECK_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_update_check.fish"
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Mock git to return newer version
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  # Test with piped input (non-interactive, answers 'n')
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    source '$DEVBASE_UPDATE_CHECK_FISH'
    echo 'n' | __devbase_update_check
  "
  
  assert_success
  assert_output --partial "DevBase Update Available"
  # In non-interactive mode, it shows the "run later" message instead of prompt
  assert_output --partial "devbase-update"
}

# =============================================================================
# Custom config update detection
# =============================================================================

@test "__devbase_update_check_custom detects when custom config has updates" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"

  git -C "$core_dir" tag -a "v2.0.0" -m "Release v2.0.0"
  
  # Get current SHA
  local current_sha
  current_sha=$(git -C "$custom_dir" rev-parse --short HEAD)
  
  # Mock git to return a different SHA for origin/main
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"rev-parse --short origin/HEAD"* ]] || [[ "\$*" == *"rev-parse --short origin/main"* ]]; then
  echo "newsha1"
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_custom
  "
  
  assert_success
  assert_output --partial "devbase-custom-config:"
  assert_output --partial "newsha1"
}

@test "__devbase_update_check_custom returns success with no output when no updates available" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"
  
  # Get current SHA
  local current_sha
  current_sha=$(git -C "$custom_dir" rev-parse --short HEAD)
  
  # Mock git to return the same SHA (no update)
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"rev-parse --short origin/HEAD"* ]] || [[ "\$*" == *"rev-parse --short origin/main"* ]]; then
  echo "${current_sha}"
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_custom
  "
  
  # Returns 0 (success) but with no output = no update available
  assert_success
  assert_output ""
}

@test "__devbase_update_check_custom skips when no custom repo exists" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  # No custom repo created
  
  run fish -c "
    set -gx HOME '$HOME'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_custom
  "
  
  assert_failure
  assert_output ""
}

# =============================================================================
# Network failure / check error handling
# =============================================================================

@test "__devbase_update_check_core reports git error when remote is unreachable" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  create_git_update_mock --offline

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_core
  "

  assert_failure
  assert_output --partial "Could not list tags"
  assert_output --partial "Could not resolve host"
}

@test "__devbase_update_check_core does not depend on fetch (tag moved upstream)" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  # fetch --tags fails when a tag was re-tagged upstream; ls-remote still works
  create_git_update_mock --fetch-fails --new-core-tag v2.0.0

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_core
  "

  assert_success
  assert_output --partial "v1.0.0 → v2.0.0"
}

@test "__devbase_update_check_custom reports git error when fetch fails" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"

  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"

  create_git_update_mock --offline

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_custom
  "

  assert_failure
  assert_output --partial "Could not fetch custom config"
  assert_output --partial "Could not resolve host"
}

@test "__devbase_update_check_core gives up on a hanging remote" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
[[ "$*" == *"ls-remote"* ]] && sleep 10
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    set -g __devbase_update_net_timeout 1
    __devbase_update_check_core
  "

  assert_failure
  assert_output --partial "Timed out after 1 seconds"
}

@test "__devbase_update_check_core explains an SSH auth failure without an agent" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "git@github.com:diggsweden/devbase-core.git"

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"ls-remote"* ]]; then
  echo "git@github.com: Permission denied (publickey)." >&2
  exit 128
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    set -gx SSH_AUTH_SOCK '${TEST_DIR}/no-agent.sock'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_core
  "

  assert_failure
  assert_output --partial "Permission denied (publickey)"
  assert_output --partial "ssh-agent is not running or not reachable"
}

@test "devbase-update fails with the git reason when the check fails" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  create_git_update_mock --offline

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null

  assert_failure
  assert_output --partial "Could not resolve host"
  assert_output --partial "Could not check for updates"
  refute_output --partial "Already up to date"
}

@test "devbase-update --check stays silent when the check fails" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  create_git_update_mock --offline

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "

  assert_failure
  assert_output ""
}

# =============================================================================
# Update flow tests
# =============================================================================

@test "devbase-update performs core update in non-interactive mode" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  git -C "$core_dir" tag -a "v2.0.0" -m "Release v2.0.0"
  
  # Create a mock setup.sh that records its arguments and, like the real one, knows the flag
  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
# accepts: --keep-preferences
echo "Setup completed with: $*"
exit 0
SCRIPT
  chmod +x "$core_dir/setup.sh"
  
  # Track which git operations were called
  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${TEST_DIR}/logs"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/logs/git_calls.log"
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
if [[ "\$*" == *"describe"* ]]; then
  echo "v1.0.0"
  exit 0
fi
if [[ "\$*" == *"checkout"* ]]; then
  exit 0
fi
if [[ "\$*" == *"stash"* ]]; then
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  # Non-interactive mode auto-proceeds with update (stdin from /dev/null)
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    mkdir -p '${TEST_DIR}/unrelated-cwd'
    cd '${TEST_DIR}/unrelated-cwd'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null
  
  assert_success
  assert_output --partial "Updates available"
  assert_output --partial "devbase-core:"
  assert_output --partial "v2.0.0"
  assert_output --partial "Non-interactive mode"
  # Updates reuse the saved preferences instead of asking again, and say how to change them
  assert_output --partial "run devbase-reconfigure afterwards"
  assert_output --partial "Setup completed with: --keep-preferences"
  
  # Verify checkout was called
  run cat "${TEST_DIR}/logs/git_calls.log"
  assert_output --partial "checkout"
}

@test "devbase-update preserves existing WSL VS Code settings file" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  git -C "$core_dir" tag -a "v2.0.0" -m "Release v2.0.0"

  mkdir -p "${HOME}/.vscode-server/data/Machine"
  printf '{"workbench.colorTheme":"Nord"}\n' > "${HOME}/.vscode-server/data/Machine/settings.json"

  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -e
test -f "$HOME/.vscode-server/data/Machine/settings.json"
grep -q 'Nord' "$HOME/.vscode-server/data/Machine/settings.json"
echo "Setup completed"
SCRIPT
  chmod +x "$core_dir/setup.sh"

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123\trefs/tags/v1.0.0"
  echo "def456\trefs/tags/v2.0.0"
  exit 0
fi
if [[ "\$*" == *"describe"* ]]; then
  echo "v1.0.0"
  exit 0
fi
if [[ "\$*" == *"checkout"* ]]; then
  exit 0
fi
if [[ "\$*" == *"stash"* ]]; then
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null

  assert_success
  assert_output --partial "Setup completed"
  assert_file_exists "${HOME}/.vscode-server/data/Machine/settings.json"

  run grep -q 'Nord' "${HOME}/.vscode-server/data/Machine/settings.json"
  assert_success
}

@test "devbase-update --ref uses requested git ref" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  git -C "$core_dir" branch "feature/test-branch"

  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
echo "Setup completed"
exit 0
SCRIPT
  chmod +x "$core_dir/setup.sh"

  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${TEST_DIR}/logs"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/logs/git_calls.log"
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123\trefs/tags/v1.0.0"
  echo "def456\trefs/tags/v2.0.0"
  exit 0
fi
if [[ "\$*" == *"checkout"* ]]; then
  exit 0
fi
if [[ "\$*" == *"stash"* ]]; then
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --ref feature/test-branch
  " </dev/null

  assert_success

  run cat "${TEST_DIR}/logs/git_calls.log"
  # The requested ref is fetched explicitly, then checked out
  assert_output --partial "fetch --depth 1 origin +refs/tags/feature/test-branch:refs/tags/feature/test-branch"
  assert_output --partial "checkout feature/test-branch"
}

@test "devbase-update --ref=<ref> uses requested git ref" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  git -C "$core_dir" branch "feature/test-sha"

  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
echo "Setup completed"
exit 0
SCRIPT
  chmod +x "$core_dir/setup.sh"

  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${TEST_DIR}/logs"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/logs/git_calls.log"
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123\trefs/tags/v1.0.0"
  echo "def456\trefs/tags/v2.0.0"
  exit 0
fi
if [[ "\$*" == *"checkout"* ]]; then
  exit 0
fi
if [[ "\$*" == *"stash"* ]]; then
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --ref=feature/test-sha
  " </dev/null

  assert_success

  run cat "${TEST_DIR}/logs/git_calls.log"
  # The requested ref is fetched explicitly, then checked out
  assert_output --partial "fetch --depth 1 origin +refs/tags/feature/test-sha:refs/tags/feature/test-sha"
  assert_output --partial "checkout feature/test-sha"
}

@test "devbase-update --check returns update info without performing update" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Mock git to return newer version
  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${TEST_DIR}/logs"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/logs/git_calls.log"
if [[ "\$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "
  
  assert_success
  assert_output --partial "devbase-core:"
  assert_output --partial "v1.0.0"
  assert_output --partial "v2.0.0"
  
  # Verify no checkout was called (check-only mode)
  run cat "${TEST_DIR}/logs/git_calls.log"
  refute_output --partial "checkout"
}

@test "devbase-update reports already up to date when no updates available" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Mock git - return same version as current (no update available)
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'MOCKSCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote"* ]]; then
  printf "abc123\trefs/tags/v1.0.0\n"
  exit 0
fi
exec /usr/bin/git "$@"
MOCKSCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  local mock_path="${TEST_DIR}/bin:${PATH}"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$mock_path'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null
  
  assert_success
  assert_output --partial "Already up to date"
}

@test "devbase-update --snooze skips prompting" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"

  # Mock git to show an update available
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'MOCKSCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123\trefs/tags/v1.0.0"
  echo "def456\trefs/tags/v2.0.0"
  exit 0
fi
exec /usr/bin/git "$@"
MOCKSCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --snooze 24
    devbase-update
  " </dev/null

  assert_success
  assert_output --partial "Updates snoozed for 24 hour(s)"
  refute_output --partial "Updates available:"
}

@test "devbase-update stores snooze under XDG_CONFIG_HOME" {
  local xdg_config_home="${TEST_DIR}/custom-config"
  mkdir -p "$xdg_config_home/devbase"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx XDG_CONFIG_HOME '$xdg_config_home'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --snooze 24
  "

  assert_success
  assert_file_exists "$xdg_config_home/devbase/update-snooze"
}

@test "devbase-update updates both core and custom when both have updates" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"
  
  # Create a mock setup.sh
  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
echo "Setup completed"
exit 0
SCRIPT
  chmod +x "$core_dir/setup.sh"
  
  # Mock git for both core and custom updates
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
# Any describe form: the installed version is v1.0.0, even though v2.0.0 is tagged locally
if [[ "$*" == *"describe --tags"* ]]; then
  echo "v1.0.0"
  exit 0
fi
if [[ "$*" == *"rev-parse --short origin/HEAD"* ]] || [[ "$*" == *"rev-parse --short origin/main"* ]]; then
  echo "newsha1"
  exit 0
fi
if [[ "$*" == *"checkout"* ]] || [[ "$*" == *"stash"* ]] || [[ "$*" == *"reset"* ]]; then
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  # Ensure the tag exists in the real repo for ref validation
  git -C "$core_dir" tag -a "v2.0.0" -m "Release v2.0.0"
  
  # Non-interactive mode auto-proceeds (stdin from /dev/null)
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null
  
  assert_success
  assert_output --partial "devbase-core:"
  assert_output --partial "devbase-custom-config:"
  assert_output --partial "Setup completed"
}

# =============================================================================
# SemVer pre-release tag support (vX.Y.Z-beta.N, vX.Y.Z-rc.N)
# =============================================================================

@test "__devbase_update_get_latest_tag returns latest beta tag when no release tags" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-beta.0" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0-beta.0"
  echo "def456	refs/tags/v1.0.0-beta.1"
  echo "ghi789	refs/tags/v1.0.0-beta.10"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_latest_tag 'https://github.com/diggsweden/devbase-core.git'
  "
  
  assert_success
  assert_output "v1.0.0-beta.10"
}

@test "__devbase_update_get_latest_tag returns latest rc tag over beta tags" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-beta.5" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0-beta.1"
  echo "def456	refs/tags/v1.0.0-beta.5"
  echo "ghi789	refs/tags/v1.0.0-rc.1"
  echo "jkl012	refs/tags/v1.0.0-rc.2"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_latest_tag 'https://github.com/diggsweden/devbase-core.git'
  "
  
  assert_success
  assert_output "v1.0.0-rc.2"
}

@test "__devbase_update_get_latest_tag returns release tag over rc and beta tags" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-rc.3" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0-beta.10"
  echo "def456	refs/tags/v1.0.0-rc.3"
  echo "ghi789	refs/tags/v1.0.0"
  echo "jkl012	refs/tags/v0.9.0"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_latest_tag 'https://github.com/diggsweden/devbase-core.git'
  "
  
  assert_success
  assert_output "v1.0.0"
}

@test "devbase-update --check detects beta tag update" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-beta.0" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0-beta.0"
  echo "def456	refs/tags/v1.0.0-beta.1"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "
  
  assert_success
  assert_output --partial "v1.0.0-beta.0"
  assert_output --partial "v1.0.0-beta.1"
}

@test "devbase-update --check detects rc tag update" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-rc.1" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0-rc.1"
  echo "def456	refs/tags/v1.0.0-rc.2"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    devbase-update --check
  "
  
  assert_success
  assert_output --partial "v1.0.0-rc.1"
  assert_output --partial "v1.0.0-rc.2"
}

@test "__devbase_update_get_latest_tag ignores alpha tags" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0-alpha.6" "https://github.com/diggsweden/devbase-core.git"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == *"fetch"* ]]; then
  exit 0
fi
if [[ "$*" == *"ls-remote --tags"* ]]; then
  # Only alpha tags available - should not trigger update
  echo "abc123	refs/tags/v1.0.0-alpha.6"
  echo "def456	refs/tags/v1.0.0-alpha.7"
  exit 0
fi
exec /usr/bin/git "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_get_latest_tag 'https://github.com/diggsweden/devbase-core.git'
  "
  
  # Should fail because no recognized tags found (alpha not supported)
  assert_failure
}

# --- Ubuntu version gate on the update path ---

_fish_os_gate() {
  local osfile="$1" fn="$2"
  fish -c "
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_too_old.fish'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_upgrade_notice.fish'
    set -gx DEVBASE_OS_RELEASE_FILE '$osfile'
    $fn
  "
}

_write_os_release() {
  printf 'ID=%s\nVERSION_ID="%s"\n' "$2" "$3" >"$1"
}

@test "updates are blocked on Ubuntu below the minimum release" {
  _write_os_release "$TEST_DIR/os" ubuntu 24.04
  run _fish_os_gate "$TEST_DIR/os" "__devbase_ubuntu_too_old"
  assert_success
}

@test "updates are allowed on Ubuntu at or above the minimum release" {
  for v in 26.04 26.10 28.04; do
    _write_os_release "$TEST_DIR/os" ubuntu "$v"
    run _fish_os_gate "$TEST_DIR/os" "__devbase_ubuntu_too_old"
    assert_failure
  done
}

@test "updates are blocked on an older release from the same year" {
  _write_os_release "$TEST_DIR/os" ubuntu 25.10
  run _fish_os_gate "$TEST_DIR/os" "__devbase_ubuntu_too_old"
  assert_success
}

@test "updates are not blocked on a non-Ubuntu distro" {
  _write_os_release "$TEST_DIR/os" fedora 45
  run _fish_os_gate "$TEST_DIR/os" "__devbase_ubuntu_too_old"
  assert_failure
}

@test "updates are not blocked when os-release cannot be read" {
  run _fish_os_gate "$TEST_DIR/does-not-exist" "__devbase_ubuntu_too_old"
  assert_failure
}

@test "the upgrade notice names the current release and the target" {
  _write_os_release "$TEST_DIR/os" ubuntu 24.04
  run _fish_os_gate "$TEST_DIR/os" "__devbase_ubuntu_upgrade_notice"
  assert_success
  assert_output --partial "You are on Ubuntu 24.04"
  assert_output --partial "require Ubuntu 26.04"
  assert_output --partial "Upgrade Ubuntu to 26.04 or later"
  assert_output --partial "Back up your work"
}

@test "devbase-update refuses on an old Ubuntu without touching the core repo" {
  # Without the gate the repo advances to a version setup.sh then refuses to
  # install, while --check reports "already up to date".
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  git -C "$core_dir" tag -a "v2.0.0" -m "Release v2.0.0"

  printf '#!/usr/bin/env bash\necho "Setup completed"\n' >"$core_dir/setup.sh"
  chmod +x "$core_dir/setup.sh"

  mkdir -p "${TEST_DIR}/bin" "${TEST_DIR}/logs"
  cat > "${TEST_DIR}/bin/git" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/logs/git_calls.log"
if [[ "\$*" == *"ls-remote --tags"* ]]; then
  echo "abc123	refs/tags/v1.0.0"
  echo "def456	refs/tags/v2.0.0"
  exit 0
fi
exec /usr/bin/git "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"${TEST_DIR}/os-release"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '${TEST_DIR}/bin' \$PATH
    set -gx DEVBASE_OS_RELEASE_FILE '${TEST_DIR}/os-release'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_too_old.fish'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_upgrade_notice.fish'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null

  assert_failure
  assert_output --partial "Upgrade Ubuntu to 26.04 or later"
  refute_output --partial "Setup completed"

  # The repo must not have moved: no checkout, no stash.
  run cat "${TEST_DIR}/logs/git_calls.log"
  refute_output --partial "checkout"
}

@test "shell-start check shows the upgrade notice instead of an update prompt" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"${TEST_DIR}/os-release"

  run fish -c "
    set -gx HOME '$HOME'
    set -gx DEVBASE_OS_RELEASE_FILE '${TEST_DIR}/os-release'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_too_old.fish'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_ubuntu_upgrade_notice.fish'
    source '$DEVBASE_UPDATE_FISH'
    source '${DEVBASE_ROOT}/dot/.config/fish/functions/__devbase_update_check.fish'
    function devbase-update; echo 'devbase-core: v1.0.0 -> v2.0.0'; end
    __devbase_update_check
  " </dev/null

  assert_success
  assert_output --partial "Upgrade Ubuntu to 26.04 or later"
  refute_output --partial "Update now?"
  refute_output --partial "DevBase Update Available"
}


# --- Real git against a local bare repo acting as the provider (no network) ---

_git_quiet() { git -c commit.gpgsign=false -c tag.gpgsign=false -c user.name=Test -c user.email=t@t "$@"; }

_make_upstream_and_core() {
  export GIT_CONFIG_NOSYSTEM=1
  PROVIDER="${TEST_DIR}/provider.git"
  WORK="${TEST_DIR}/work"
  CORE="${HOME}/.local/share/devbase/core"
  _git_quiet init --quiet --bare --initial-branch=main "$PROVIDER"
  _git_quiet init --quiet --initial-branch=main "$WORK"
  _git_quiet -C "$WORK" remote add origin "file://${PROVIDER}"
  # Each release carries a setup.sh that records how it was called
  printf '%s\n' '#!/usr/bin/env bash' '# accepts: --keep-preferences' \
    'echo "setup $(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD) args: $*"' >"$WORK/setup.sh"
  chmod +x "$WORK/setup.sh"
  _git_quiet -C "$WORK" add setup.sh && _git_quiet -C "$WORK" commit -qm one
  _git_quiet -C "$WORK" tag -a v1.0.0 -m v1.0.0
  _git_quiet -C "$WORK" push -q origin main v1.0.0
  # Like persist.sh: shallow, single-branch, pinned to the release tag
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch v1.0.0 "file://${PROVIDER}" "$CORE"
  # The provider moves on after the install: a new release and a feature branch
  echo two >"$WORK/notes" && _git_quiet -C "$WORK" add notes && _git_quiet -C "$WORK" commit -qm two
  _git_quiet -C "$WORK" tag -a v2.0.0 -m v2.0.0
  _git_quiet -C "$WORK" switch -qc feat/x
  echo three >"$WORK/notes" && _git_quiet -C "$WORK" commit -qam three
  _git_quiet -C "$WORK" push -q origin main v2.0.0 feat/x
}

_run_update_fish() {
  # Shipped functions on the autoload path, nothing else from the host
  run fish --no-config -c "
    set -gx HOME '$HOME'
    set fish_function_path '${DEVBASE_ROOT}/dot/.config/fish/functions' \$fish_function_path
    function mise; end
    function __devbase_ubuntu_too_old; return 1; end
    source '$DEVBASE_UPDATE_FISH'
    $1
  " </dev/null
}

@test "update_core fetches a release tag a single-branch clone has never seen" {
  _make_upstream_and_core
  _run_update_fish "__devbase_update_core v2.0.0"
  assert_success
  assert_output --partial "Core updated to v2.0.0"
  assert_equal "$(git -C "$CORE" rev-parse HEAD)" "$(git -C "$PROVIDER" rev-parse 'v2.0.0^{commit}')"
}

@test "update_core fetches a branch a single-branch clone has never seen" {
  _make_upstream_and_core
  _run_update_fish "__devbase_update_core feat/x"
  assert_success
  assert_equal "$(git -C "$CORE" rev-parse HEAD)" "$(git -C "$PROVIDER" rev-parse feat/x)"
}

@test "update_core reports a ref that exists neither as tag nor branch" {
  _make_upstream_and_core
  _run_update_fish "__devbase_update_core v9.9.9"
  assert_failure
  assert_output --partial "Ref not found in core repo: v9.9.9"
  # The installed version is left untouched
  assert_equal "$(git -C "$CORE" rev-parse HEAD)" "$(git -C "$PROVIDER" rev-parse 'v1.0.0^{commit}')"
}

@test "an untagged core shows its commit instead of unknown" {
  _make_upstream_and_core
  git -C "$CORE" fetch -q --depth 1 origin "+refs/heads/feat/x:refs/remotes/origin/feat/x"
  git -C "$CORE" -c advice.detachedHead=false checkout -q origin/feat/x
  _run_update_fish '__devbase_update_get_core_info; and echo "tag=$CORE_TAG"'
  assert_success
  assert_output "tag=untagged $(git -C "$CORE" rev-parse --short HEAD)"
}

@test "devbase-update --yes updates to the latest release end to end without a second prompt" {
  _make_upstream_and_core
  _run_update_fish "devbase-update --yes"
  assert_success
  assert_output --partial "devbase-core: v1.0.0 → v2.0.0"
  assert_output --partial "Proceeding with update"
  refute_output --partial "Proceed with update?"
  # The new release's own setup.sh ran, with saved preferences kept
  assert_output --partial "setup v2.0.0 args: --keep-preferences"
  assert_equal "$(git -C "$CORE" rev-parse HEAD)" "$(git -C "$PROVIDER" rev-parse 'v2.0.0^{commit}')"
}

@test "devbase-update reports up to date against the provider when already on the latest release" {
  _make_upstream_and_core
  git -C "$CORE" fetch -q --depth 1 origin "+refs/tags/v2.0.0:refs/tags/v2.0.0"
  git -C "$CORE" -c advice.detachedHead=false checkout -q v2.0.0
  _run_update_fish "devbase-update --yes"
  assert_success
  assert_output --partial "Already up to date (core: v2.0.0)"
  refute_output --partial "setup "
}

@test "devbase-update passes --yes to the update and nothing leaks into later calls" {
  run fish --no-config -c "
    source '$DEVBASE_UPDATE_FISH'
    function __devbase_update_do_update; echo \"assume=[\$argv[2]]\"; end
    devbase-update --yes
    devbase-update
    set -q __devbase_update_assume_yes; and echo LEAKED
    true
  "
  assert_success
  assert_line --index 0 "assume=[yes]"
  assert_line --index 1 "assume=[]"
  refute_output --partial LEAKED
}

@test "update_core refreshes a branch the clone already has instead of using the stale copy" {
  _make_upstream_and_core
  # A core installed from the main branch: the clone has a local `main` that falls behind
  rm -rf "$CORE"
  git clone --quiet --depth 1 --branch main "file://${PROVIDER}" "$CORE"
  _git_quiet -C "$WORK" switch -q main
  echo four >"$WORK/notes" && _git_quiet -C "$WORK" commit -qam four
  _git_quiet -C "$WORK" push -q origin main
  _run_update_fish "__devbase_update_core main"
  assert_success
  assert_equal "$(git -C "$CORE" rev-parse HEAD)" "$(git -C "$PROVIDER" rev-parse main)"
}

@test "update_core keeps local changes in place when the ref does not exist" {
  _make_upstream_and_core
  echo local >"$CORE/local-change"
  git -C "$CORE" add local-change
  _run_update_fish "__devbase_update_core no-such-ref"
  assert_failure
  assert_file_exists "$CORE/local-change"
  run git -C "$CORE" stash list
  assert_output ""
}

@test "update_core reports an unreachable provider as a fetch failure, not a missing ref" {
  _make_upstream_and_core
  git -C "$CORE" remote set-url origin "file://${TEST_DIR}/gone.git"
  _run_update_fish "set -g CORE_REMOTE file://${TEST_DIR}/gone.git; __devbase_update_core v2.0.0"
  assert_failure
  assert_output --partial "Could not fetch v2.0.0"
  refute_output --partial "Ref not found"
}

@test "update_core rejects short and full SHAs as refs" {
  _make_upstream_and_core
  _run_update_fish "__devbase_update_core abc1234"
  assert_failure
  assert_output --partial "SHA refs are not supported"
}

@test "a full-history core ahead of its last tag is untagged, not that tag" {
  _make_upstream_and_core
  rm -rf "$CORE"
  git clone --quiet "file://${PROVIDER}" "$CORE"
  # main moves one commit past v2.0.0
  _git_quiet -C "$WORK" switch -q main
  echo five >"$WORK/notes" && _git_quiet -C "$WORK" commit -qam five
  _git_quiet -C "$WORK" push -q origin main
  git -C "$CORE" pull -q
  _run_update_fish '__devbase_update_get_core_info; and echo "tag=$CORE_TAG"'
  assert_success
  assert_output "tag=untagged $(git -C "$CORE" rev-parse --short HEAD)"
}

# A git wrapper that fails the first $FLAKY_FAILS network calls with $FLAKY_MSG,
# then hands everything to the real git. Calls are counted in $FLAKY_LOG.
_install_flaky_git() {
  local real_git
  real_git=$(command -v git)
  mkdir -p "${TEST_DIR}/flaky-bin"
  cat >"${TEST_DIR}/flaky-bin/git" <<SCRIPT
#!/usr/bin/env bash
case " \$* " in
  *" ls-remote "*|*" fetch "*)
    echo "\$*" >>"${TEST_DIR}/flaky.log"
    n=\$(wc -l <"${TEST_DIR}/flaky.log")
    if [ "\$n" -le "${1}" ]; then echo "${2}" >&2; exit 128; fi ;;
esac
exec "${real_git}" "\$@"
SCRIPT
  chmod +x "${TEST_DIR}/flaky-bin/git"
}

_run_with_flaky_git() {
  _run_update_fish "set -gx PATH '${TEST_DIR}/flaky-bin' \$PATH; set -g __devbase_update_net_retry_delay 0; $1"
}

@test "a dropped connection is retried and the update completes" {
  _make_upstream_and_core
  _install_flaky_git 1 "fatal: unable to access 'x': Could not resolve host: github.com"
  _run_with_flaky_git "devbase-update --yes"
  assert_success
  assert_output --partial "Attempt 1/3 failed, retrying"
  assert_output --partial "setup v2.0.0 args: --keep-preferences"
}

@test "an authentication failure is not retried" {
  _make_upstream_and_core
  _install_flaky_git 9 "git@github.com: Permission denied (publickey)."
  _run_with_flaky_git "devbase-update --yes"
  assert_failure
  refute_output --partial "retrying"
  assert_equal "$(wc -l <"${TEST_DIR}/flaky.log")" 1
}

@test "retries stop after three attempts and say so" {
  _make_upstream_and_core
  _install_flaky_git 9 "ssh: connect to host github.com port 22: Connection timed out"
  _run_with_flaky_git "devbase-update --yes"
  assert_failure
  assert_output --partial "Gave up after 3 attempts"
  assert_equal "$(wc -l <"${TEST_DIR}/flaky.log")" 3
}

@test "a normal update asks the provider for tags once" {
  _make_upstream_and_core
  _install_flaky_git 0 ""
  _run_with_flaky_git "devbase-update --yes"
  assert_success
  assert_equal "$(grep -c 'ls-remote' "${TEST_DIR}/flaky.log")" 1
}

@test "the silent shell-start check does not retry" {
  _make_upstream_and_core
  _install_flaky_git 9 "ssh: connect to host github.com port 22: Connection timed out"
  _run_with_flaky_git "devbase-update --check; true"
  assert_success
  refute_output --partial "retrying"
  assert_equal "$(wc -l <"${TEST_DIR}/flaky.log")" 1
}
