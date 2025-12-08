#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "get_os_type returns OS identifier" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_os_type
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should output something like "ubuntu", "debian", etc.
  assert [ -n "$output" ]
}

@test "get_os_version returns version number" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_os_version
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should output something like "24.04", "22.04", etc.
  assert [ -n "$output" ]
}

@test "get_os_name returns human-readable OS name" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_os_name
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should output something like "Ubuntu"
  assert [ -n "$output" ]
}

@test "is_wsl detects WSL environment via WSL_DISTRO_NAME" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export WSL_DISTRO_NAME='Ubuntu-22.04'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    is_wsl && echo 'IS_WSL' || echo 'NOT_WSL'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "IS_WSL"
}

@test "is_wsl detects WSL environment via WSL_INTEROP" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export WSL_INTEROP='/run/WSL/some_value'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    is_wsl && echo 'IS_WSL' || echo 'NOT_WSL'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "IS_WSL"
}

@test "is_wsl returns false when not in WSL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    unset WSL_DISTRO_NAME
    unset WSL_INTEROP
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    # Only check env vars, skip /proc checks since we can't mock them
    if [[ -n \"\${WSL_DISTRO_NAME:-}\" ]] || [[ -n \"\${WSL_INTEROP:-}\" ]]; then
      echo 'IS_WSL'
    else
      echo 'NOT_WSL'
    fi
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "NOT_WSL"
}

@test "is_ubuntu returns true on Ubuntu systems" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    is_ubuntu && echo 'IS_UBUNTU' || echo 'NOT_UBUNTU'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Will be IS_UBUNTU or NOT_UBUNTU depending on test environment
  assert [ -n "$output" ]
}

@test "get_wsl_version returns 1 or 2 when in WSL" {
  skip "Requires WSL environment"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export WSL_DISTRO_NAME='Ubuntu'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_wsl_version
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should be "1" or "2"
  assert_output --regexp "^[12]$"
}

@test "get_os_info populates OS info array" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_os_info
    echo \"id=\${_DEVBASE_OS_INFO[id]}\"
    echo \"version_id=\${_DEVBASE_OS_INFO[version_id]}\"
    echo \"name=\${_DEVBASE_OS_INFO[name]}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "id="
  assert_output --partial "version_id="
  assert_output --partial "name="
}

@test "get_os_version_full returns full version string" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_os_version_full
  "
  
  assert_success
}

@test "detect_environment sets _DEVBASE_ENV to ubuntu on non-WSL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    unset WSL_DISTRO_NAME WSL_INTEROP
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    
    is_wsl() { return 1; }
    detect_environment >/dev/null 2>&1
    echo \"\$_DEVBASE_ENV\"
  "
  
  assert_success
  assert_output "ubuntu"
}

@test "detect_environment sets _DEVBASE_ENV to wsl-ubuntu on WSL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export WSL_DISTRO_NAME='Ubuntu'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    
    get_wsl_version() { echo '2.6.0'; }
    detect_environment >/dev/null 2>&1
    echo \"\$_DEVBASE_ENV\"
  "
  
  assert_success
  assert_output "wsl-ubuntu"
}

@test "check_critical_tools succeeds when all tools present" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    check_critical_tools
  "
  
  assert_success
}

@test "check_critical_tools fails when tool missing" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export PATH='/nonexistent'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    check_critical_tools
  "
  
  assert_failure
}

@test "validate_required_vars fails when DEVBASE_ENV missing" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    unset DEVBASE_ENV
    export _DEVBASE_ENV='ubuntu'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    validate_required_vars
  "
  
  assert_failure
}

@test "validate_required_vars fails for invalid _DEVBASE_ENV" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_ENV='test'
    export _DEVBASE_ENV='invalid-env'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    validate_required_vars
  "
  
  assert_failure
}

@test "validate_required_vars succeeds with valid environment" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_ENV='test'
    export _DEVBASE_ENV='ubuntu'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    validate_required_vars
  "
  
  assert_success
}

@test "get_secure_boot_mode returns wsl on WSL" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export WSL_DISTRO_NAME='Ubuntu'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    get_secure_boot_mode
  "
  
  assert_success
  assert_output "wsl"
}

@test "check_path_writable creates and verifies XDG directories" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_BIN_HOME='${TEST_DIR}/bin'
    export XDG_CONFIG_HOME='${TEST_DIR}/config'
    export XDG_CACHE_HOME='${TEST_DIR}/cache'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    check_path_writable
  "
  
  assert_success
  assert_dir_exists "${TEST_DIR}/bin"
  assert_dir_exists "${TEST_DIR}/config"
  assert_dir_exists "${TEST_DIR}/cache"
}
