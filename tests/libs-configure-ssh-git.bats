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
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run run_with_proxy "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_proxy
  " "proxy.example.com" "8080" "${TEST_DIR}/bin"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
}

@test "configure_git_proxy skips when no proxy configured" {
  run run_isolated "
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

@test "setup_ssh_config_includes appends known_hosts.append to known_hosts" {
  local test_home="${TEST_DIR}/home"
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  mkdir -p "${custom_ssh}"
  
  # Create a known_hosts.append file with test content
  cat > "${custom_ssh}/known_hosts.append" << 'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
EOF
  
  run bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH='${custom_ssh}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    setup_ssh_config_includes
    
    cat '${test_home}/.ssh/known_hosts'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "github.com ssh-ed25519"
  assert_output --partial "gitlab.com ssh-ed25519"
}

@test "setup_ssh_config_includes does not duplicate known_hosts entries" {
  local test_home="${TEST_DIR}/home"
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  mkdir -p "${custom_ssh}"
  
  # Pre-populate known_hosts with one entry
  echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > "${test_home}/.ssh/known_hosts"
  
  # Create known_hosts.append with same entry plus a new one
  cat > "${custom_ssh}/known_hosts.append" << 'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
EOF
  
  bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH='${custom_ssh}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    setup_ssh_config_includes
  " >/dev/null 2>&1
  
  # Count occurrences of github.com - should be exactly 1
  run grep -c "github.com" "${test_home}/.ssh/known_hosts"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "1"
}

@test "configure_ssh processes known_hosts.append even when key action is skip" {
  local test_home="${TEST_DIR}/home"
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  mkdir -p "${custom_ssh}"
  
  # Create known_hosts.append
  echo "example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest" > "${custom_ssh}/known_hosts.append"
  
  run bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH='${custom_ssh}'
    export DEVBASE_SSH_KEY_ACTION='skip'
    export DEVBASE_SSH_KEY_TYPE='ed25519'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_ssh
    
    cat '${test_home}/.ssh/known_hosts'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "example.com ssh-ed25519"
}

@test "setup_ssh_config_includes handles append file without trailing newline" {
  local test_home="${TEST_DIR}/home"
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  mkdir -p "${custom_ssh}"
  
  # Create known_hosts.append WITHOUT trailing newline
  # This simulates files that don't end with a newline character
  printf "example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest" > "${custom_ssh}/known_hosts.append"
  
  run bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export _DEVBASE_CUSTOM_SSH='${custom_ssh}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    setup_ssh_config_includes
    
    cat '${test_home}/.ssh/known_hosts'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should contain the host key even though file has no trailing newline
  assert_output --partial "example.com ssh-ed25519"
}

@test "configure_git_signing creates allowed_signers in XDG config dir" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${test_home}/.ssh/id_ed25519.pub"
  
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
# Accept all git config commands
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_signing
    
    test -f '${test_home}/.config/ssh/allowed_signers' && echo 'FILE_EXISTS'
    cat '${test_home}/.config/ssh/allowed_signers'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "FILE_EXISTS"
  assert_output --partial "test@example.com"
  assert_output --partial "ssh-ed25519"
}

@test "configure_git_signing sets correct git config values" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"

  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${test_home}/.ssh/id_ed25519.pub"

  # Git mock that logs all config calls
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "config" ]]; then
  echo "git config $*" >> "${HOME}/.git-config-log"
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'

    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1

    configure_git_signing

    cat '${test_home}/.git-config-log'
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "gpg.format ssh"
  assert_output --partial "user.signingkey ${test_home}/.ssh/id_ed25519.pub"
  assert_output --partial "gpg.ssh.allowedSignersFile ${test_home}/.config/ssh/allowed_signers"
}

@test "configure_git_signing fails when signing key does not exist" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  # No signing key created
  
  run bash -c "
    export PATH='/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_signing
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_failure
}

@test "configure_git_signing does not duplicate key in allowed_signers" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${test_home}/.ssh/id_ed25519.pub"
  
  # Pre-populate allowed_signers with the same key
  echo "test@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${test_home}/.config/ssh/allowed_signers"
  
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_signing
  " >/dev/null 2>&1
  
  # Count lines - should still be 1
  run wc -l < "${test_home}/.config/ssh/allowed_signers"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "1"
}

@test "configure_git_signing preserves existing signers when adding new key" {
  local test_home="${TEST_DIR}/home"
  mkdir -p "${test_home}/.ssh"
  mkdir -p "${test_home}/.config/ssh"
  
  # Create a mock signing key (different from existing)
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKey test@example.com" > "${test_home}/.ssh/id_ed25519.pub"
  
  # Pre-populate allowed_signers with a DIFFERENT existing key
  echo "other@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherKey other@example.com" > "${test_home}/.config/ssh/allowed_signers"
  
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"
  
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${test_home}'
    export XDG_CONFIG_HOME='${test_home}/.config'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_NAME='id_ed25519'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1
    
    configure_git_signing
  " >/dev/null 2>&1
  
  # Should have 2 lines now (existing + new)
  run wc -l < "${test_home}/.config/ssh/allowed_signers"
  assert_success
  assert_output "2"
  
  # Verify both keys are present
  run grep -c "OtherKey" "${test_home}/.config/ssh/allowed_signers"
  assert_success
  assert_output "1"
  
  run grep -c "NewKey" "${test_home}/.config/ssh/allowed_signers"
  assert_success
  assert_output "1"
}
