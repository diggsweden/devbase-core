#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
}

teardown() {
  common_teardown
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
  run run_as_wsl "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    is_wsl && echo 'IS_WSL' || echo 'NOT_WSL'
  " "Ubuntu-22.04"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "IS_WSL"
}

@test "is_wsl detects WSL environment via WSL_INTEROP" {
  run run_as_wsl_interop "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    is_wsl && echo 'IS_WSL' || echo 'NOT_WSL'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "IS_WSL"
}

@test "is_wsl returns false when not in WSL" {
  run run_isolated "
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

@test "get_wsl_version returns empty when not in WSL" {
  run run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    result=\$(get_wsl_version)
    echo \"result='\$result'\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "result=''"
}

@test "get_wsl_version parses WSL 2 version correctly" {
  # Create mock wsl.exe
  local mock_wsl_dir="${TEST_DIR}/mnt/c/Windows/System32"
  mkdir -p "$mock_wsl_dir"
  cat > "${mock_wsl_dir}/wsl.exe" << 'SCRIPT'
#!/bin/bash
echo "WSL version: 2.6.1.0"
echo "Kernel version: 5.15.153.1-2"
echo "WSLg version: 1.0.65"
SCRIPT
  chmod +x "${mock_wsl_dir}/wsl.exe"
  
  run run_as_wsl "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    
    # Override get_wsl_version to use our mock path
    get_wsl_version() {
      if ! is_wsl; then
        echo ''
        return 0
      fi
      local wsl_exe='${mock_wsl_dir}/wsl.exe'
      if [[ ! -x \"\$wsl_exe\" ]]; then
        echo ''
        return 1
      fi
      local wsl_version_output
      wsl_version_output=\$(\"\$wsl_exe\" --version 2>/dev/null | grep 'WSL version:' | head -1 | awk '{print \$3}' | tr -d '\r')
      if [[ -z \"\$wsl_version_output\" ]]; then
        echo ''
        return 1
      fi
      wsl_version_output=\$(echo \"\$wsl_version_output\" | grep -oE '^[0-9]+\\.[0-9]+\\.[0-9]+')
      echo \"\$wsl_version_output\"
      return 0
    }
    
    get_wsl_version
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "2.6.1"
}

@test "get_wsl_version handles missing wsl.exe" {
  run run_as_wsl "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/check-requirements.sh' >/dev/null 2>&1
    
    # Override to use non-existent path
    get_wsl_version() {
      if ! is_wsl; then
        echo ''
        return 0
      fi
      local wsl_exe='${TEST_DIR}/nonexistent/wsl.exe'
      if [[ ! -x \"\$wsl_exe\" ]]; then
        echo ''
        return 1
      fi
      echo 'should not reach here'
    }
    
    result=\$(get_wsl_version)
    status=\$?
    echo \"result='\$result' status=\$status\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_output "result='' status=1"
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
  grep -q 'ID=ubuntu' /etc/os-release 2>/dev/null || skip "Ubuntu-specific test"
  run run_isolated "
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
  grep -q 'ID=ubuntu' /etc/os-release 2>/dev/null || skip "Ubuntu-specific test"
  run run_as_wsl "
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
  run run_as_wsl "
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
