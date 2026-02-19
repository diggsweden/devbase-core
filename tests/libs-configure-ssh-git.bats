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
  common_setup_isolated
  export USER="testuser"
  mkdir -p "${TEST_DIR}/bin"

  export PATH="${TEST_DIR}/bin:/usr/bin:/bin"
  source_core_libs
  source "${DEVBASE_ROOT}/libs/configure-ssh-git.sh"
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

  export DEVBASE_GIT_AUTHOR='testauthor'
  export DEVBASE_GIT_EMAIL='test@example.com'

  run --separate-stderr configure_git_user

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

  export DEVBASE_GIT_AUTHOR='testauthor'
  export DEVBASE_GIT_EMAIL='test@example.com'

  run --separate-stderr configure_git_user

  assert_success
  assert_output "existing"
}

@test "configure_git_proxy sets http.proxy when proxy configured" {
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  run run_with_proxy "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1

    configure_git_proxy
  " "proxy.example.com" "8080" "${TEST_DIR}/bin"

  assert_success
}

@test "configure_git_proxy skips when no proxy configured" {
  run run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-ssh-git.sh' >/dev/null 2>&1

    configure_git_proxy
    echo 'COMPLETED'
  "

  assert_success
  assert_output "COMPLETED"
}

@test "setup_ssh_config_includes creates SSH config directory" {
  mkdir -p "${HOME}/.ssh"
  export _DEVBASE_CUSTOM_SSH=''

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_dir_exists "${HOME}/.ssh"
}

@test "setup_ssh_config_includes sets correct permissions on .ssh directory" {
  mkdir -p "${HOME}/.ssh"
  export _DEVBASE_CUSTOM_SSH=''

  setup_ssh_config_includes >/dev/null 2>&1

  run stat -c '%a' "${HOME}/.ssh"

  assert_success
  assert_output "700"
}

@test "setup_ssh_config_includes appends known_hosts.append to known_hosts" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  # Create a known_hosts.append file with test content
  cat > "${custom_ssh}/known_hosts.append" << 'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
EOF

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  setup_ssh_config_includes >/dev/null 2>&1

  run cat "${HOME}/.ssh/known_hosts"

  assert_success
  assert_output --partial "github.com ssh-ed25519"
  assert_output --partial "gitlab.com ssh-ed25519"
}

@test "setup_ssh_config_includes does not duplicate known_hosts entries" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  # Pre-populate known_hosts with one entry
  echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > "${HOME}/.ssh/known_hosts"

  # Create known_hosts.append with same entry plus a new one
  cat > "${custom_ssh}/known_hosts.append" << 'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
EOF

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  setup_ssh_config_includes >/dev/null 2>&1

  # Count occurrences of github.com - should be exactly 1
  run grep -c "github.com" "${HOME}/.ssh/known_hosts"

  assert_success
  assert_output "1"
}

@test "configure_ssh processes known_hosts.append even when key action is skip" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  # Create known_hosts.append
  echo "example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest" > "${custom_ssh}/known_hosts.append"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"
  export DEVBASE_SSH_KEY_ACTION='skip'
  export DEVBASE_SSH_KEY_TYPE='ed25519'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  # configure_ssh also needs configure-services, source it inline
  source "${DEVBASE_ROOT}/libs/configure-services.sh" >/dev/null 2>&1

  configure_ssh >/dev/null 2>&1

  run cat "${HOME}/.ssh/known_hosts"

  assert_success
  assert_output --partial "example.com ssh-ed25519"
}

@test "setup_ssh_config_includes handles append file without trailing newline" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  # Create known_hosts.append WITHOUT trailing newline
  printf "example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest" > "${custom_ssh}/known_hosts.append"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  setup_ssh_config_includes >/dev/null 2>&1

  run cat "${HOME}/.ssh/known_hosts"

  assert_success
  # Should contain the host key even though file has no trailing newline
  assert_output --partial "example.com ssh-ed25519"
}

@test "setup_ssh_config_includes copies allowlisted pub key to .ssh" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest" >"${custom_ssh}/id_ed25519_corp.pub"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_file_exists "${HOME}/.ssh/id_ed25519_corp.pub"
}

@test "setup_ssh_config_includes blocks unrecognised files with warning" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  echo "something" >"${custom_ssh}/authorized_keys2"
  echo "something" >"${custom_ssh}/environment"
  echo "something" >"${custom_ssh}/rc"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  # Dangerous files must NOT be copied
  assert_file_not_exists "${HOME}/.ssh/authorized_keys2"
  assert_file_not_exists "${HOME}/.ssh/environment"
  assert_file_not_exists "${HOME}/.ssh/rc"
  # Warning emitted for each skipped file (show_progress warning → stdout)
  assert_output --partial "authorized_keys2"
}

@test "configure_git_signing creates allowed_signers in XDG config dir" {
  mkdir -p "${HOME}/.ssh"

  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${HOME}/.ssh/id_ed25519.pub"

  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  export DEVBASE_GIT_EMAIL='test@example.com'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  configure_git_signing >/dev/null 2>&1

  assert_file_exists "${XDG_CONFIG_HOME}/ssh/allowed_signers"
  run cat "${XDG_CONFIG_HOME}/ssh/allowed_signers"
  assert_output --partial "test@example.com"
  assert_output --partial "ssh-ed25519"
}

@test "configure_git_signing sets correct git config values" {
  mkdir -p "${HOME}/.ssh"

  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${HOME}/.ssh/id_ed25519.pub"

  # Git mock that logs all config calls
  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "config" ]]; then
  echo "git config $*" >> "${HOME}/.git-config-log"
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  export DEVBASE_GIT_EMAIL='test@example.com'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  configure_git_signing >/dev/null 2>&1

  run cat "${HOME}/.git-config-log"

  assert_success
  assert_output --partial "gpg.format ssh"
  assert_output --partial "user.signingkey ${HOME}/.ssh/id_ed25519.pub"
  assert_output --partial "gpg.ssh.allowedSignersFile ${XDG_CONFIG_HOME}/ssh/allowed_signers"
}

@test "configure_git_signing fails when signing key does not exist" {
  mkdir -p "${HOME}/.ssh"
  # No signing key created

  export DEVBASE_GIT_EMAIL='test@example.com'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  run --separate-stderr configure_git_signing

  assert_failure
}

@test "configure_git_signing does not duplicate key in allowed_signers" {
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${XDG_CONFIG_HOME}/ssh"

  # Create a mock signing key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${HOME}/.ssh/id_ed25519.pub"

  # Pre-populate allowed_signers with the same key
  echo "test@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey test@example.com" > "${XDG_CONFIG_HOME}/ssh/allowed_signers"

  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  export DEVBASE_GIT_EMAIL='test@example.com'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  configure_git_signing >/dev/null 2>&1

  # Count lines - should still be 1
  run wc -l < "${XDG_CONFIG_HOME}/ssh/allowed_signers"

  assert_success
  assert_output "1"
}

@test "configure_git_signing preserves existing signers when adding new key" {
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${XDG_CONFIG_HOME}/ssh"

  # Create a mock signing key (different from existing)
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKey test@example.com" > "${HOME}/.ssh/id_ed25519.pub"

  # Pre-populate allowed_signers with a DIFFERENT existing key
  echo "other@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherKey other@example.com" > "${XDG_CONFIG_HOME}/ssh/allowed_signers"

  cat > "${TEST_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/git"

  export DEVBASE_GIT_EMAIL='test@example.com'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  configure_git_signing >/dev/null 2>&1

  # Should have 2 lines now (existing + new)
  run wc -l < "${XDG_CONFIG_HOME}/ssh/allowed_signers"
  assert_success
  assert_output "2"

  # Verify both keys are present
  run grep -c "OtherKey" "${XDG_CONFIG_HOME}/ssh/allowed_signers"
  assert_success
  assert_output "1"

  run grep -c "NewKey" "${XDG_CONFIG_HOME}/ssh/allowed_signers"
  assert_success
  assert_output "1"
}
