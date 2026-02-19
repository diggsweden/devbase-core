#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  source_core_libs
  source "${DEVBASE_ROOT}/libs/utils.sh"
}

teardown() {
  common_teardown
}

@test "generate_ssh_passphrase returns 24 character string" {
  run --separate-stderr generate_ssh_passphrase

  assert_success
  assert [ ${#output} -eq 24 ]
}

@test "generate_ssh_passphrase generates different passphrases" {
  local pass1
  local pass2
  pass1=$(generate_ssh_passphrase)
  pass2=$(generate_ssh_passphrase)
  
  assert [ "$pass1" != "$pass2" ]
}

@test "command_exists returns 0 for existing command" {
  run --separate-stderr command_exists bash
  
  assert_success
}

@test "command_exists returns 1 for non-existing command" {
  run --separate-stderr command_exists nonexistentcommand123456
  
  assert_failure
}

@test "command_exists caches results" {
  command_exists bash
  
  run --separate-stderr bash -c "[[ -n \"\${COMMAND_CACHE[bash]:-}\" ]] && echo 'cached'"
  
  assert [ -n "${COMMAND_CACHE[bash]:-}" ]
}

@test "ensure_user_dirs creates XDG directories" {
  local test_home="${TEST_DIR}/home"
  export HOME="$test_home"
  export XDG_CONFIG_HOME="${test_home}/.config"
  export XDG_DATA_HOME="${test_home}/.local/share"
  export XDG_CACHE_HOME="${test_home}/.cache"
  export XDG_BIN_HOME="${test_home}/.local/bin"
  export DEVBASE_CONFIG_DIR="${test_home}/.config/devbase"
  export DEVBASE_CACHE_DIR="${test_home}/.cache/devbase"
  export DEVBASE_BACKUP_DIR="${test_home}/.devbase_backup"
  
  run --separate-stderr ensure_user_dirs
  
  assert_success
  assert_dir_exists "${test_home}/.config"
  assert_dir_exists "${test_home}/.local/share"
  assert_dir_exists "${test_home}/.local/bin"
}

@test "backup_if_exists creates backup of existing file" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  
  run --separate-stderr backup_if_exists "$test_file" 'bak'
  
  assert_file_exists "${test_file}-bak"
  run cat "${test_file}-bak"
  assert_output "test content"
}

@test "backup_if_exists preserves file content" {
  local test_file="${TEST_DIR}/testfile"
  echo "original content" > "$test_file"
  
  run --separate-stderr backup_if_exists "$test_file" 'backup'
  
  assert_file_exists "${test_file}-backup"
  assert_file_not_exists "${test_file}"
  run cat "${test_file}-backup"
  assert_output "original content"
}

@test "backup_if_exists handles duplicate backups" {
  local test_file="${TEST_DIR}/testfile"
  
  echo "content1" > "$test_file"
  backup_if_exists "$test_file" 'bak'
  
  echo "content2" > "$test_file"
  run --separate-stderr backup_if_exists "$test_file" 'bak'
  
  assert_file_exists "${test_file}-bak"
  assert_file_exists "${test_file}-bak-1"
  run cat "${test_file}-bak"
  assert_output "content1"
  run cat "${test_file}-bak-1"
  assert_output "content2"
}

@test "backup_if_exists handles non-existent file gracefully" {
  local test_file="${TEST_DIR}/nonexistent"
  
  run --separate-stderr backup_if_exists "$test_file" 'nonexistent-backup'
  
  assert_success
}

@test "command_exists uses cache to avoid repeated lookups" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/test_command" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/test_command"
  
  export PATH="${TEST_DIR}/bin:${PATH}"
  
  command_exists test_command
  command_exists test_command
  
  assert [ -n "${COMMAND_CACHE[test_command]:-}" ]
}

@test "retry_command with mocked failing command" {
  local attempt_file="${TEST_DIR}/attempts"
  echo "0" > "$attempt_file"
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/flaky_command" << SCRIPT
#!/usr/bin/env bash
attempts=\$(cat '${attempt_file}')
attempts=\$((attempts + 1))
echo "\$attempts" > '${attempt_file}'

if [[ "\$attempts" -lt 3 ]]; then
  echo "Attempt \$attempts failed" >&2
  exit 1
else
  echo "Success on attempt \$attempts"
  exit 0
fi
SCRIPT
  chmod +x "${TEST_DIR}/bin/flaky_command"
  
  export PATH="${TEST_DIR}/bin:${PATH}"
  
  run --separate-stderr retry_command --delay 0 -- flaky_command
  
  assert_success
  assert_output --partial "Success on attempt 3"
}
