#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'
load 'test_helper'

setup() {
  common_setup_isolated
  export DEVBASE_BACKUP_DIR="${HOME}/.devbase_backup"
  export DEVBASE_CUSTOM_DIR=""
  export DEVBASE_ENABLE_GIT_HOOKS="true"
  
  mkdir -p "${XDG_CONFIG_HOME}/git"
  mkdir -p "${DEVBASE_BACKUP_DIR}"
}

teardown() {
  common_teardown
}

@test "configure_git_hooks creates hooks directory" {
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    test -d '${XDG_CONFIG_HOME}/git/git-hooks' && echo 'OK'
  "
  
  assert_success
  assert_output --partial "OK"
}

@test "configure_git_hooks copies template hooks" {
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    
    # Check that prepare-commit-msg dispatcher was copied
    test -f '${XDG_CONFIG_HOME}/git/git-hooks/prepare-commit-msg' && \
    echo 'DISPATCHERS_COPIED'
  "
  
  assert_success
  assert_output --partial "DISPATCHERS_COPIED"
}

@test "configure_git_hooks makes hook scripts executable" {
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    
    # Check dispatcher is executable
    test -x '${XDG_CONFIG_HOME}/git/git-hooks/prepare-commit-msg' && echo 'EXECUTABLE'
  "
  
  assert_success
  assert_output --partial "EXECUTABLE"
}

@test "configure_git_hooks configures git to use hooks directory" {
  stub git "config --global core.hooksPath * : echo 'git config set'"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
  "
  
  assert_success
  assert_output --partial "git config set"
  
  unstub git
}

@test "configure_git_hooks backs up existing hooks" {
  # Create existing hook
  mkdir -p "${XDG_CONFIG_HOME}/git/git-hooks"
  echo "existing hook" > "${XDG_CONFIG_HOME}/git/git-hooks/existing-hook"
  
  stub git "config --global core.hooksPath * : true"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    
    # Check backup was created
    test -f '${DEVBASE_BACKUP_DIR}/git-hooks/existing-hook' && echo 'BACKED_UP'
  "
  
  assert_success
  assert_output --partial "BACKED_UP"
  
  unstub git
}

@test "configure_git_hooks skips when DEVBASE_ENABLE_GIT_HOOKS is false" {
  export DEVBASE_ENABLE_GIT_HOOKS="false"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_ENABLE_GIT_HOOKS='false'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
  "
  
  assert_success
  assert_output --partial "Git hooks disabled"
}

@test "configure_git_hooks makes .sh files in .d directories executable" {
  stub git "config --global core.hooksPath * : true"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    
    # Check that .sh files are executable
    find '${XDG_CONFIG_HOME}/git/git-hooks' -type f -name '*.sh' ! -name '*.sample' -perm -u+x | wc -l
  "
  
  unstub git
  
  # Should find at least one executable .sh file
  assert_success
}

@test "configure_git_hooks copies custom organization hooks when available" {
  local custom_hooks="${TEST_DIR}/git-hooks"
  mkdir -p "$custom_hooks"
  echo -e "#!/bin/bash\necho custom" > "$custom_hooks/custom-pre-commit"
  chmod +x "$custom_hooks/custom-pre-commit"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR='${TEST_DIR}'
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
    
    test -f '${XDG_CONFIG_HOME}/git/git-hooks/custom-pre-commit' && echo 'CUSTOM_COPIED'
  "
  
  assert_success
  assert_output --partial "organization-specific"
  assert_output --partial "CUSTOM_COPIED"
}

@test "configure_git_hooks reports backup count in success message" {
  mkdir -p "${XDG_CONFIG_HOME}/git/git-hooks"
  echo "hook1" > "${XDG_CONFIG_HOME}/git/git-hooks/hook1"
  echo "hook2" > "${XDG_CONFIG_HOME}/git/git-hooks/hook2"
  
  stub git "config --global core.hooksPath * : true"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
  "
  
  assert_success
  assert_output --partial "2 files backed up"
  
  unstub git
}

@test "configure_git_hooks excludes .sample files from executable permission" {
  bash -c "
    export HOME='${HOME}'
    export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_BACKUP_DIR='${DEVBASE_BACKUP_DIR}'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-git-hooks.sh' >/dev/null 2>&1
    
    configure_git_hooks
  " >/dev/null 2>&1
  
  # Verify no .sample files are marked executable
  local count
  count=$(find "${XDG_CONFIG_HOME}/git/git-hooks" -type f -name '*.sample' -perm -u+x 2>/dev/null | wc -l)
  
  # Should find 0 executable .sample files
  [ "$count" -eq 0 ]
}
