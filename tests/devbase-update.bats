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
