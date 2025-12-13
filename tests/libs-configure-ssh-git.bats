#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup
  export USER="testuser"
  mkdir -p "${TEST_DIR}/bin"
}

teardown() {
  common_teardown
}

@test "configure_git_user sets git config when values differ" {
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "config" && "$2" == "--global" && "$3" == "user.name" && -z "$4" ]]; then
  echo "oldname"
elif [[ "$1" == "config" && "$2" == "--global" && "$3" == "user.email" && -z "$4" ]]; then
  echo "old@example.com"
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export USER='${USER}'
    export DEVBASE_GIT_AUTHOR='testauthor'
    export DEVBASE_GIT_EMAIL='test@example.com'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_user
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "true"
}

@test "configure_git_user returns existing when config matches" {
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "config" && "$2" == "--global" && "$3" == "user.name" && -z "$4" ]]; then
  echo "testauthor"
elif [[ "$1" == "config" && "$2" == "--global" && "$3" == "user.email" && -z "$4" ]]; then
  echo "test@example.com"
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export USER='${USER}'
    export DEVBASE_GIT_AUTHOR='testauthor'
    export DEVBASE_GIT_EMAIL='test@example.com'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_user
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "existing"
}

@test "configure_git_proxy sets http.proxy when proxy configured" {
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_PROXY_HOST='proxy.example.com'
    export DEVBASE_PROXY_PORT='8080'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_proxy
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
}

@test "configure_git_proxy skips when no proxy configured" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    unset DEVBASE_PROXY_HOST
    unset DEVBASE_PROXY_PORT
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_proxy
    echo 'COMPLETED'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "COMPLETED"
}

@test "setup_ssh_config_includes creates SSH config directory" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  run bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    setup_ssh_config_includes
    
    test -d '${test_home}/.ssh' && echo 'SSH_DIR_EXISTS'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "SSH_DIR_EXISTS"
}

@test "setup_ssh_config_includes sets correct permissions on .ssh directory" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    setup_ssh_config_includes
  " >/dev/null 2>&1
  
  run stat -c '%a' "${test_home}/.ssh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "700"
}
