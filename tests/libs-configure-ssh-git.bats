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
  # shellcheck disable=SC2153 # DEVBASE_ROOT is set by common_setup_isolated
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/configure-ssh-git.sh"
  export _DEVBASE_CUSTOM_TEMPLATES=''
  export _DEVBASE_CUSTOM_SSH=''
}

teardown() {
  common_teardown
}

# Exercise the real dotfile deployment before SSH setup, as installation does.
deploy_ssh_configuration() {
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/process-templates.sh"
  export USER="$(id -un)"
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_TEMP="$(mktemp -d "${TEST_DIR}/staging.XXXXXX")"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"
  export DEVBASE_SSH_KEY_ACTION='keep'
  export DEVBASE_SSH_KEY_TYPE='ed25519'
  export DEVBASE_SSH_KEY_NAME='id_ed25519'

  local temp_dotfiles
  temp_dotfiles=$(prepare_temp_dotfiles_directory) || return 1
  merge_dotfiles_with_backup "$temp_dotfiles" || return 1
  configure_ssh
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

@test "SSH installation creates a personal config when missing" {
  run --separate-stderr deploy_ssh_configuration

  assert_success
  assert_file_exists "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_equal "$(stat -c %a "${XDG_CONFIG_HOME}/ssh/user.config")" "600"
  run cat "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_output --partial "# Personal SSH Configuration"
}

@test "SSH installation and reinstallation preserve personal config" {
  mkdir -p "${XDG_CONFIG_HOME}/ssh"
  printf 'Host personal\n  HostName personal.example.com\n' >"${TEST_DIR}/expected.config"
  cp "${TEST_DIR}/expected.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  chmod 600 "${XDG_CONFIG_HOME}/ssh/user.config"

  run --separate-stderr deploy_ssh_configuration

  assert_success
  assert_files_equal "${TEST_DIR}/expected.config" "${XDG_CONFIG_HOME}/ssh/user.config"

  printf '\nHost added-later\n  User personal\n' >>"${XDG_CONFIG_HOME}/ssh/user.config"
  cp "${XDG_CONFIG_HOME}/ssh/user.config" "${TEST_DIR}/expected.config"

  run --separate-stderr deploy_ssh_configuration

  assert_success
  assert_files_equal "${TEST_DIR}/expected.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_equal "$(stat -c %a "${XDG_CONFIG_HOME}/ssh/user.config")" "600"
}

@test "SSH deployment preserves learned and revoked hosts across both organization seed paths" {
  mkdir -p "${HOME}/.ssh" "${TEST_DIR}/custom_ssh" "${TEST_DIR}/templates"
  cat >"${TEST_DIR}/expected_hosts" <<'EOF'
# Personal trust decisions
|1|hashed-host|hashed-name ssh-ed25519 personal-key
@revoked old.example.com ssh-ed25519 revoked-key
@cert-authority *.example.com ssh-ed25519 trusted-ca
EOF
  cp "${TEST_DIR}/expected_hosts" "${HOME}/.ssh/known_hosts"
  echo 'old.example.com ssh-ed25519 revoked-key' >"${TEST_DIR}/custom_ssh/known_hosts.append"
  echo 'new.example.com ssh-ed25519 new-key' >"${TEST_DIR}/templates/known_hosts.append"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"
  export _DEVBASE_CUSTOM_TEMPLATES="${TEST_DIR}/templates"

  run deploy_ssh_configuration
  assert_success
  assert_files_equal "${TEST_DIR}/expected_hosts" "${HOME}/.ssh/known_hosts"
  run deploy_ssh_configuration
  assert_success
  assert_files_equal "${TEST_DIR}/expected_hosts" "${HOME}/.ssh/known_hosts"
}

@test "SSH fresh initialization collects both organization known_hosts sources once" {
  mkdir -p "${TEST_DIR}/custom_ssh" "${TEST_DIR}/templates"
  echo 'ssh.example.com ssh-ed25519 ssh-key' >"${TEST_DIR}/custom_ssh/known_hosts.append"
  printf 'template.example.com ssh-ed25519 template-key' >"${TEST_DIR}/templates/known_hosts.append"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"
  export _DEVBASE_CUSTOM_TEMPLATES="${TEST_DIR}/templates"

  run deploy_ssh_configuration
  assert_success
  assert_equal "$(stat -c %a "${HOME}/.ssh/known_hosts")" "600"
  run cat "${HOME}/.ssh/known_hosts"
  assert_output --partial 'github.com ssh-ed25519'
  assert_output --partial 'ssh.example.com ssh-ed25519 ssh-key'
  assert_output --partial 'template.example.com ssh-ed25519 template-key'

  cp "${HOME}/.ssh/known_hosts" "${TEST_DIR}/expected_hosts"
  echo 'later.example.com ssh-ed25519 later-key' >>"${TEST_DIR}/custom_ssh/known_hosts.append"
  run deploy_ssh_configuration
  assert_success
  assert_files_equal "${TEST_DIR}/expected_hosts" "${HOME}/.ssh/known_hosts"
}

@test "SSH known_hosts preserves empty files and symlinks" {
  mkdir -p "${HOME}/.ssh"
  touch "${HOME}/.ssh/known_hosts"
  run setup_ssh_config_includes
  assert_success
  assert [ ! -s "${HOME}/.ssh/known_hosts" ]

  rm "${HOME}/.ssh/known_hosts"
  ln -s "${TEST_DIR}/personal_hosts" "${HOME}/.ssh/known_hosts"
  run setup_ssh_config_includes
  assert_success
  assert_symlink_to "${TEST_DIR}/personal_hosts" "${HOME}/.ssh/known_hosts"
  assert_file_not_exists "${TEST_DIR}/personal_hosts"

  echo '# Personal trust' >"${TEST_DIR}/personal_hosts"
  run setup_ssh_config_includes
  assert_success
  assert_equal "$(cat "${TEST_DIR}/personal_hosts")" '# Personal trust'
}

@test "setup_ssh_config_includes preserves personal config while updating organization config" {
  mkdir -p "${XDG_CONFIG_HOME}/ssh" "${TEST_DIR}/custom_ssh"
  printf 'Host personal\n  User personal\n' >"${TEST_DIR}/expected.config"
  cp "${TEST_DIR}/expected.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  echo '# Old organization config' >"${XDG_CONFIG_HOME}/ssh/custom.config"
  echo '# Organization personal defaults' >"${TEST_DIR}/custom_ssh/user.config"
  echo '# Updated organization config' >"${TEST_DIR}/custom_ssh/custom.config"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_files_equal "${TEST_DIR}/expected.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_files_equal "${TEST_DIR}/custom_ssh/custom.config" "${XDG_CONFIG_HOME}/ssh/custom.config"
}

@test "setup_ssh_config_includes seeds missing personal config from organization defaults" {
  mkdir -p "${TEST_DIR}/custom_ssh"
  echo '# Organization personal defaults' >"${TEST_DIR}/custom_ssh/user.config"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_files_equal "${TEST_DIR}/custom_ssh/user.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_equal "$(stat -c %a "${XDG_CONFIG_HOME}/ssh/user.config")" "600"
}

@test "setup_ssh_config_includes preserves an intentionally empty personal config" {
  mkdir -p "${XDG_CONFIG_HOME}/ssh" "${TEST_DIR}/custom_ssh"
  touch "${XDG_CONFIG_HOME}/ssh/user.config"
  echo '# Organization personal defaults' >"${TEST_DIR}/custom_ssh/user.config"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_file_exists "${XDG_CONFIG_HOME}/ssh/user.config"
  assert [ ! -s "${XDG_CONFIG_HOME}/ssh/user.config" ]
}

@test "setup_ssh_config_includes preserves symlinked personal config and its contents" {
  mkdir -p "${XDG_CONFIG_HOME}/ssh" "${TEST_DIR}/custom_ssh"
  printf 'Host personal\n  User personal\n' >"${TEST_DIR}/expected.config"
  cp "${TEST_DIR}/expected.config" "${TEST_DIR}/linked.config"
  ln -s "${TEST_DIR}/linked.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  echo '# Organization personal defaults' >"${TEST_DIR}/custom_ssh/user.config"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_symlink_to "${TEST_DIR}/linked.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_files_equal "${TEST_DIR}/expected.config" "${TEST_DIR}/linked.config"
}

@test "setup_ssh_config_includes preserves a dangling personal config symlink" {
  mkdir -p "${XDG_CONFIG_HOME}/ssh" "${TEST_DIR}/custom_ssh"
  ln -s "${TEST_DIR}/missing.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  export _DEVBASE_CUSTOM_SSH=''

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_symlink_to "${TEST_DIR}/missing.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_file_not_exists "${TEST_DIR}/missing.config"

  echo '# Organization personal defaults' >"${TEST_DIR}/custom_ssh/user.config"
  export _DEVBASE_CUSTOM_SSH="${TEST_DIR}/custom_ssh"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_symlink_to "${TEST_DIR}/missing.config" "${XDG_CONFIG_HOME}/ssh/user.config"
  assert_file_not_exists "${TEST_DIR}/missing.config"
}

@test "setup_ssh_config_includes seeds missing known_hosts with organization entries" {
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
  assert_equal "$(stat -c %a "${HOME}/.ssh/id_ed25519_corp.pub")" "600"
}

@test "setup_ssh_config_includes copies legacy 'identity' key to .ssh" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh"
  mkdir -p "${custom_ssh}"

  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDTest" >"${custom_ssh}/identity"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_file_exists "${HOME}/.ssh/identity"
  # The allowlist admits id_*, identity and *.pem, all of which can hold
  # private key material, so assert the mode and not just the copy.
  assert_equal "$(stat -c %a "${HOME}/.ssh/identity")" "600"
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

@test "setup_ssh_config_includes copies a config fragment with owner-only permissions" {
  local custom_ssh="${TEST_DIR}/custom_ssh"
  mkdir -p "${HOME}/.ssh" "${custom_ssh}"

  # Config fragments come from the organisation's custom SSH directory and can
  # carry internal hostnames or a ProxyCommand with credentials.
  printf 'Host internal\n  HostName internal.example\n' >"${custom_ssh}/org.config"

  export _DEVBASE_CUSTOM_SSH="${custom_ssh}"

  run --separate-stderr setup_ssh_config_includes

  assert_success
  assert_file_exists "${XDG_CONFIG_HOME}/ssh/org.config"
  assert_equal "$(stat -c %a "${XDG_CONFIG_HOME}/ssh/org.config")" "600"
  # Existence and mode alone pass even if the fragment is copied empty.
  run cat "${XDG_CONFIG_HOME}/ssh/org.config"
  assert_output --partial "HostName internal.example"
}
