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

# =============================================================================
# _calculate_safe_relative_path tests
#
# The traversal guard for merge_dotfiles_with_backup: the result is appended
# to both the backup and the target directory.
# =============================================================================

@test "_calculate_safe_relative_path strips the source directory prefix" {
  run --separate-stderr _calculate_safe_relative_path "/src/.config/fish/config.fish" "/src"
  assert_success
  assert_output ".config/fish/config.fish"
}

@test "_calculate_safe_relative_path rejects a traversal segment" {
  run --separate-stderr _calculate_safe_relative_path "/src/../../etc/passwd" "/src"
  assert_failure
  refute_output --partial "etc/passwd"
}

@test "_calculate_safe_relative_path rejects a file outside the source directory" {
  # The prefix strip leaves the path absolute, which must not be accepted:
  # joined onto the target it would resolve to /etc/passwd, not below it.
  run --separate-stderr _calculate_safe_relative_path "/etc/passwd" "/src"
  assert_failure
}

# =============================================================================
# merge_dotfiles_with_backup tests
# =============================================================================

@test "merge_dotfiles_with_backup backs up an existing file before overwriting it" {
  local src="${TEST_DIR}/src" target="${TEST_DIR}/target"
  mkdir -p "$src/.config" "$target/.config"
  echo "new" > "$src/.config/app.conf"
  echo "original" > "$target/.config/app.conf"
  export DEVBASE_BACKUP_DIR="${TEST_DIR}/backup"

  run --separate-stderr merge_dotfiles_with_backup "$src" "$target"

  assert_success
  assert_equal "$(cat "$target/.config/app.conf")" "new"
  assert_equal "$(cat "${TEST_DIR}/backup/dot_backup/.config/app.conf")" "original"
}

@test "merge_dotfiles_with_backup copies files that the target does not have" {
  local src="${TEST_DIR}/src" target="${TEST_DIR}/target"
  mkdir -p "$src" "$target"
  echo "fresh" > "$src/.newrc"
  export DEVBASE_BACKUP_DIR="${TEST_DIR}/backup"

  run --separate-stderr merge_dotfiles_with_backup "$src" "$target"

  assert_success
  assert_equal "$(cat "$target/.newrc")" "fresh"
  assert_file_not_exists "${TEST_DIR}/backup/dot_backup/.newrc"
}

@test "merge_dotfiles_with_backup backs up an existing symlink without following it" {
  local src="${TEST_DIR}/src" target="${TEST_DIR}/target"
  mkdir -p "$src" "$target"
  echo "secret" > "${TEST_DIR}/outside"
  ln -s "${TEST_DIR}/outside" "$target/.linkrc"
  echo "replacement" > "$src/.linkrc"
  export DEVBASE_BACKUP_DIR="${TEST_DIR}/backup"

  run --separate-stderr merge_dotfiles_with_backup "$src" "$target"

  assert_success
  # The backup must be the link itself, not a copy of what it pointed at.
  assert_symlink_to "${TEST_DIR}/outside" "${TEST_DIR}/backup/dot_backup/.linkrc"
}

@test "merge_dotfiles_with_backup fails when the source directory is missing" {
  export DEVBASE_BACKUP_DIR="${TEST_DIR}/backup"
  run --separate-stderr merge_dotfiles_with_backup "${TEST_DIR}/absent" "${TEST_DIR}/target"
  assert_failure
  # Assert which check rejected it: the later cp fails on a missing source
  # directory too, with a far less useful error.
  assert_regex "$stderr$output" "Source directory not found"
}

@test "merge_dotfiles_with_backup rejects an empty source directory" {
  export DEVBASE_BACKUP_DIR="${TEST_DIR}/backup"
  run --separate-stderr merge_dotfiles_with_backup "" "${TEST_DIR}/target"
  assert_failure
  # validate_path would also stop this, but only by calling die.
  assert_regex "$stderr$output" "source directory is required"
}

# =============================================================================
# _extract_uppercase_vars tests
# =============================================================================

@test "_extract_uppercase_vars finds both brace and bare uppercase forms" {
  run --separate-stderr _extract_uppercase_vars 'a ${FIRST} b $SECOND c'
  assert_success
  assert_output --partial '$FIRST'
  assert_output --partial '$SECOND'
}

@test "_extract_uppercase_vars ignores lowercase variables" {
  run --separate-stderr _extract_uppercase_vars 'keep $lower and ${mixed_Case} alone'
  assert_success
  refute_output --partial 'lower'
  refute_output --partial 'mixed'
}

@test "_extract_uppercase_vars reports a repeated variable once" {
  run --separate-stderr _extract_uppercase_vars '$DUPE and ${DUPE} again $DUPE'
  assert_success
  assert_equal "$(printf '%s' "$output" | grep -o 'DUPE' | wc -l)" "1"
}

# =============================================================================
# envsubst_preserve_undefined tests
# =============================================================================

@test "envsubst_preserve_undefined substitutes a set uppercase variable" {
  printf 'theme is $DEVBASE_THEME\n' > "${TEST_DIR}/in.tpl"
  export DEVBASE_THEME="nord"

  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/in.tpl" "${TEST_DIR}/out"

  assert_success
  assert_equal "$(cat "${TEST_DIR}/out")" "theme is nord"
}

@test "envsubst_preserve_undefined leaves lowercase shell variables untouched" {
  printf 'set -l dir $lower_var\n' > "${TEST_DIR}/in.tpl"

  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/in.tpl" "${TEST_DIR}/out"

  assert_success
  assert_equal "$(cat "${TEST_DIR}/out")" 'set -l dir $lower_var'
}

# These are expanded by the shell when the rendered file runs, so they must
# survive templating even though they are uppercase and set here.
@test "envsubst_preserve_undefined preserves runtime variables even when they are set" {
  printf 'sock=$XDG_RUNTIME_DIR/x uid=$USER_UID\n' > "${TEST_DIR}/in.tpl"
  export XDG_RUNTIME_DIR="/run/user/1000" USER_UID="1000"

  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/in.tpl" "${TEST_DIR}/out"

  assert_success
  assert_equal "$(cat "${TEST_DIR}/out")" 'sock=$XDG_RUNTIME_DIR/x uid=$USER_UID'
}

@test "envsubst_preserve_undefined copies a template that has no variables" {
  printf 'plain content\n' > "${TEST_DIR}/in.tpl"

  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/in.tpl" "${TEST_DIR}/out"

  assert_success
  assert_equal "$(cat "${TEST_DIR}/out")" "plain content"
}

@test "envsubst_preserve_undefined fails when a required variable is unset" {
  printf 'editor is $EDITOR\n' > "${TEST_DIR}/in.tpl"
  unset EDITOR

  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/in.tpl" "${TEST_DIR}/out"

  assert_failure
  assert_regex "$stderr$output" "EDITOR"
  # A failed render must not leave a half-substituted file behind.
  assert_file_not_exists "${TEST_DIR}/out"
}

@test "envsubst_preserve_undefined fails when the template file does not exist" {
  run --separate-stderr envsubst_preserve_undefined "${TEST_DIR}/absent.tpl" "${TEST_DIR}/out"
  assert_failure
  assert_regex "$stderr$output" "Template file not found"
}

# =============================================================================
# make_temp_dir tests
#
# TMPDIR is pointed at TEST_DIR so the directory lands inside the sandbox.
# =============================================================================

@test "make_temp_dir creates a directory using the given prefix" {
  export TMPDIR="${TEST_DIR}"

  run --separate-stderr make_temp_dir "myprefix"

  assert_success
  assert_dir_exists "$output"
  assert_regex "$(basename "$output")" "^myprefix\."
}

@test "make_temp_dir falls back to the devbase prefix" {
  export TMPDIR="${TEST_DIR}"

  run --separate-stderr make_temp_dir

  assert_success
  assert_regex "$(basename "$output")" "^devbase\."
}

# =============================================================================
# run_mise_from_home_dir tests
# =============================================================================

# mise resolves config relative to the working directory, so the wrapper
# exists to force $HOME as cwd.
@test "run_mise_from_home_dir runs mise with HOME as the working directory" {
  mkdir -p "${TEST_DIR}/bin" "${TEST_DIR}/home" "${TEST_DIR}/elsewhere"
  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
printf 'cwd=%s args=%s\n' "$PWD" "$*"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"
  export PATH="${TEST_DIR}/bin:${PATH}"
  export HOME="${TEST_DIR}/home"
  cd "${TEST_DIR}/elsewhere"

  run --separate-stderr run_mise_from_home_dir install node

  assert_success
  assert_output "cwd=${TEST_DIR}/home args=install node"
}

# =============================================================================
# systemctl_enable_start / systemctl_disable_stop tests
# =============================================================================

_stub_systemctl() {
  local exit_code="$1" message="$2"
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exec "$@"
SCRIPT
  cat > "${TEST_DIR}/bin/systemctl" << SCRIPT
#!/usr/bin/env bash
[[ "\$1" == "enable" || "\$1" == "disable" ]] || exit 0
printf '%s\n' "${message}"
exit ${exit_code}
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo" "${TEST_DIR}/bin/systemctl"
  export PATH="${TEST_DIR}/bin:${PATH}"
  export DEVBASE_DEBUG=0
}

@test "systemctl_enable_start reports success without echoing systemd chatter" {
  _stub_systemctl 0 "Created symlink /etc/systemd/system/x.service"

  run --separate-stderr systemctl_enable_start "x.service" "X daemon"

  assert_success
  assert_regex "$output" "X daemon enabled and started"
  # Quiet on success: the symlink noise is only useful in debug mode.
  refute_output --partial "Created symlink"
}

@test "systemctl_enable_start shows systemd chatter in debug mode" {
  _stub_systemctl 0 "Created symlink /etc/systemd/system/x.service"
  export DEVBASE_DEBUG=1

  run --separate-stderr systemctl_enable_start "x.service" "X daemon"

  assert_success
  assert_output --partial "Created symlink"
}

# A bare "Failed to enable" tells the user nothing about why.
@test "systemctl_enable_start surfaces the systemd error when enabling fails" {
  _stub_systemctl 1 "Failed to enable unit: Unit x.service does not exist."

  run --separate-stderr systemctl_enable_start "x.service" "X daemon"

  assert_failure
  assert_regex "$stderr$output" "Unit x.service does not exist"
  assert_regex "$stderr$output" "Failed to enable X daemon"
}

@test "systemctl_enable_start rejects an empty service name" {
  _stub_systemctl 0 "unused"

  run --separate-stderr systemctl_enable_start "" "X daemon"

  assert_failure
  assert_regex "$stderr$output" "Service name is required"
}

_stub_systemctl_rc() {
  local stop_rc="$1" disable_rc="$2" message="$3"
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exec "$@"
SCRIPT
  cat > "${TEST_DIR}/bin/systemctl" << SCRIPT
#!/usr/bin/env bash
case "\$1" in
stop) exit ${stop_rc} ;;
disable) printf '%s\n' "${message}"; exit ${disable_rc} ;;
esac
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo" "${TEST_DIR}/bin/systemctl"
  export PATH="${TEST_DIR}/bin:${PATH}"
  export DEVBASE_DEBUG=0
}

@test "systemctl_disable_stop reports success when the service stops and disables" {
  _stub_systemctl_rc 0 0 "Removed /etc/systemd/system/x.service"

  run --separate-stderr systemctl_disable_stop "x.service" "X daemon"

  assert_success
  assert_regex "$output" "X daemon disabled"
  refute_output --partial "Removed /etc"
}

@test "systemctl_disable_stop surfaces the error when disabling fails" {
  _stub_systemctl_rc 0 1 "Failed to disable unit: access denied"

  run --separate-stderr systemctl_disable_stop "x.service" "X daemon"

  # Still 0 by design, but the reason must not be hidden.
  assert_success
  assert_regex "$stderr$output" "access denied"
}

# A service that was never running is not an error, and must not claim it
# disabled something it did not touch.
@test "systemctl_disable_stop stays quiet when the service is not running" {
  _stub_systemctl_rc 1 0 "unused"

  run --separate-stderr systemctl_disable_stop "x.service" "X daemon"

  assert_success
  refute_output --partial "disabled"
}

@test "systemctl_disable_stop rejects an empty service name" {
  _stub_systemctl_rc 0 0 "unused"

  run --separate-stderr systemctl_disable_stop "" "X daemon"

  assert_failure
  assert_regex "$stderr$output" "Service name is required"
}

# =============================================================================
# add_global_warning tests
# =============================================================================

@test "add_global_warning both shows the warning and keeps it for the summary" {
  DEVBASE_GLOBAL_WARNINGS=()

  run --separate-stderr add_global_warning "disk is nearly full"
  assert_success
  assert_regex "$stderr$output" "disk is nearly full"

  # run uses a subshell, so re-add to observe the accumulator itself.
  add_global_warning "disk is nearly full" >/dev/null 2>&1
  assert_equal "${#DEVBASE_GLOBAL_WARNINGS[@]}" "1"
  assert_equal "${DEVBASE_GLOBAL_WARNINGS[0]}" "disk is nearly full"
}

# =============================================================================
# sudo_refresh tests
# =============================================================================

# Refreshing the sudo timestamp is an optimisation and must never abort the
# caller.
@test "sudo_refresh succeeds when sudo declines to refresh" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo"
  export PATH="${TEST_DIR}/bin:${PATH}"

  run --separate-stderr sudo_refresh

  assert_success
}
