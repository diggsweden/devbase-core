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

@test "command_exists answers from cache after the command leaves PATH" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/test_command" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/test_command"
  
  export PATH="${TEST_DIR}/bin:${PATH}"
  
  command_exists test_command

  # A cached answer still succeeds; a re-probe would not.
  export PATH="/usr/bin:/bin"
  run command_exists test_command
  assert_success
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

@test "safe_rm_file removes a regular file" {
  local target="${TEST_DIR}/file-to-remove"
  echo "content" > "$target"

  run safe_rm_file "$target"

  assert_success
  [ ! -e "$target" ]
}

@test "safe_rm_file removes a symlink without following it" {
  local dead_target="/nonexistent/path"
  local link="${TEST_DIR}/broken-link"
  ln -sfn "$dead_target" "$link"

  run safe_rm_file "$link"

  assert_success
  [ ! -L "$link" ]
}

@test "safe_rm_file is a no-op on a missing target" {
  run safe_rm_file "${TEST_DIR}/does-not-exist"

  assert_success
}

@test "safe_rm_file refuses to remove a directory" {
  local dir="${TEST_DIR}/a-directory"
  mkdir -p "$dir"

  run --separate-stderr safe_rm_file "$dir"

  assert_failure
  assert [ -d "$dir" ]
  # The message is what proves our guard ran: rm -f refuses a directory on its
  # own, so a bare failure would only assert coreutils behaviour.
  assert [ -n "$stderr" ]
  [[ "$stderr" == *"refusing directory"* ]]
}

@test "safe_rm_file rejects empty target" {
  run --separate-stderr safe_rm_file ""

  assert_failure
}

# validate_path is the whitelist that stops devbase operating on system
# directories; safe_rm_rf is the containment check before a recursive delete.

@test "validate_path refuses a system directory" {
  run --separate-stderr validate_path '/etc' 'true'
  assert_failure
  # validate_path is layered and the final whitelist also rejects /etc, so the
  # message is what proves the system-directory arm fired.
  [[ "$stderr" == *"Cannot operate on system directory"* ]]
}

@test "validate_path refuses the filesystem root" {
  run --separate-stderr validate_path '/' 'true'
  assert_failure
}

@test "validate_path refuses a path outside the allowed zones" {
  run --separate-stderr validate_path '/srv/somewhere' 'true'
  assert_failure
  [[ "$stderr" == *"Path outside allowed zones"* ]]
}

@test "validate_path refuses a mount point" {
  run --separate-stderr validate_path '/mnt/usb' 'true'
  assert_failure
  [[ "$stderr" == *"Cannot operate on mount point"* ]]
}

@test "validate_path accepts a path under the temp directory" {
  run --separate-stderr validate_path "${TEST_DIR}/work" 'true'
  assert_success
}

@test "validate_path refuses traversal that escapes into a system directory" {
  run --separate-stderr validate_path "${TEST_DIR}/../../../etc" 'true'
  assert_failure
}

@test "safe_rm_rf removes a directory tree inside the anchor" {
  mkdir -p "${TEST_DIR}/anchor/tree/deep"
  touch "${TEST_DIR}/anchor/tree/deep/file"

  run --separate-stderr safe_rm_rf "${TEST_DIR}/anchor" "${TEST_DIR}/anchor/tree"

  assert_success
  assert [ ! -e "${TEST_DIR}/anchor/tree" ]
  assert [ -d "${TEST_DIR}/anchor" ]
}

@test "safe_rm_rf refuses to remove the anchor itself" {
  mkdir -p "${TEST_DIR}/anchor"

  run --separate-stderr safe_rm_rf "${TEST_DIR}/anchor" "${TEST_DIR}/anchor"

  assert_failure
  assert [ -d "${TEST_DIR}/anchor" ]
}

@test "safe_rm_rf refuses a target outside the anchor" {
  mkdir -p "${TEST_DIR}/anchor" "${TEST_DIR}/sibling"

  run --separate-stderr safe_rm_rf "${TEST_DIR}/anchor" "${TEST_DIR}/sibling"

  assert_failure
  assert [ -d "${TEST_DIR}/sibling" ]
}

@test "safe_rm_rf refuses traversal that escapes the anchor" {
  mkdir -p "${TEST_DIR}/anchor" "${TEST_DIR}/sibling"

  run --separate-stderr safe_rm_rf "${TEST_DIR}/anchor" "${TEST_DIR}/anchor/../sibling"

  assert_failure
  assert [ -d "${TEST_DIR}/sibling" ]
}

@test "safe_rm_rf rejects empty arguments" {
  run --separate-stderr safe_rm_rf '' "${TEST_DIR}"
  assert_failure

  run --separate-stderr safe_rm_rf "${TEST_DIR}" ''
  assert_failure
}
