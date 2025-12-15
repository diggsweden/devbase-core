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
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  setup_isolated_home
  mkdir -p "$XDG_DATA_HOME/devbase"
  
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_UPDATE_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-update.fish"
}

teardown() {
  safe_temp_del "$TEST_DIR"
}

# Helper to run fish commands with the devbase-update function loaded
run_fish_update() {
  fish -c "source '$DEVBASE_UPDATE_FISH'; $*"
}

@test "devbase-update.fish function file exists" {
  assert_file_exists "$DEVBASE_UPDATE_FISH"
}

@test "devbase-update --help shows usage" {
  run run_fish_update "devbase-update --help"
  
  assert_success
  assert_output --partial "Usage:"
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
# Network failure / offline handling
# =============================================================================

@test "__devbase_update_check_core returns failure when fetch fails (offline)" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Use helper to create git mock that fails on fetch (offline mode)
  create_git_update_mock --fetch-fails
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_core
  "
  
  assert_failure
}

@test "__devbase_update_check_custom returns failure when fetch fails (offline)" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  local custom_dir="${XDG_DATA_HOME}/devbase/custom"
  
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  create_mock_git_repo "$custom_dir" "v0.1.0" "https://github.com/myorg/custom.git"
  
  # Use helper to create git mock that fails on fetch (offline mode)
  create_git_update_mock --fetch-fails
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    __devbase_update_check_custom
  "
  
  assert_failure
}

@test "devbase-update shows offline message when both checks fail" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Use helper to create git mock that fails on fetch (offline mode)
  create_git_update_mock --fetch-fails
  
  run fish -c "
    set -gx HOME '$HOME'
    set -gx PATH '$PATH'
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null
  
  assert_success
  assert_output --partial "Offline"
}

# =============================================================================
# Update flow tests
# =============================================================================

@test "devbase-update performs core update in non-interactive mode" {
  local core_dir="${XDG_DATA_HOME}/devbase/core"
  create_mock_git_repo "$core_dir" "v1.0.0" "https://github.com/diggsweden/devbase-core.git"
  
  # Create a mock setup.sh that just succeeds
  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
echo "Setup completed"
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
    source '$DEVBASE_UPDATE_FISH'
    devbase-update
  " </dev/null
  
  assert_success
  assert_output --partial "Updates available"
  assert_output --partial "devbase-core:"
  assert_output --partial "v2.0.0"
  assert_output --partial "Non-interactive mode"
  assert_output --partial "Setup completed"
  
  # Verify checkout was called
  run cat "${TEST_DIR}/logs/git_calls.log"
  assert_output --partial "checkout"
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
