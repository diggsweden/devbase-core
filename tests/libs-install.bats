#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218,SC2329
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  # Alias for backward compatibility with tests using TEMP_DIR
  TEMP_DIR="$TEST_DIR"
  export TEMP_DIR
}

teardown() {
  common_teardown
}

@test "cleanup_temp_directory validates path pattern before removal" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  local safe_temp="${BATS_TEST_TMPDIR}/devbase.ABC123"
  mkdir -p "$safe_temp"
  export _DEVBASE_TEMP="$safe_temp"

  cleanup_temp_directory

  [[ ! -d "$safe_temp" ]]
}

@test "cleanup_temp_directory rejects unsafe paths" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  local unsafe_temp="${HOME}/important"
  mkdir -p "$unsafe_temp"
  export _DEVBASE_TEMP="$unsafe_temp"

  cleanup_temp_directory

  [[ -d "$unsafe_temp" ]]
}

@test "cleanup_temp_directory handles missing directory gracefully" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"

  export _DEVBASE_TEMP="${BATS_TEST_TMPDIR}/devbase.nonexistent"

  run --separate-stderr cleanup_temp_directory
  assert_success
}

@test "_get_theme_display_name returns correct display names" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVBASE_ROOT}/libs/theme-registry.sh"
  source <(sed -n '/^_get_theme_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_theme_display_name "everforest-dark")
  [[ "$result" == "Everforest Dark" ]]

  result=$(_get_theme_display_name "catppuccin-mocha")
  [[ "$result" == "Catppuccin Mocha" ]]

  result=$(_get_theme_display_name "tokyonight-night")
  [[ "$result" == "Tokyo Night" ]]

  result=$(_get_theme_display_name "gruvbox-light")
  [[ "$result" == "Gruvbox Light" ]]
}

@test "_get_theme_display_name returns original for unknown themes" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVBASE_ROOT}/libs/theme-registry.sh"
  source <(sed -n '/^_get_theme_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_theme_display_name "unknown-theme")
  [[ "$result" == "unknown-theme" ]]
}

@test "_get_font_display_name returns correct font names" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVBASE_ROOT}/libs/font-registry.sh"
  source <(sed -n '/^_get_font_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_font_display_name "jetbrains-mono")
  [[ "$result" == "JetBrains Mono Nerd Font" ]]

  result=$(_get_font_display_name "firacode")
  [[ "$result" == "Fira Code Nerd Font" ]]

  result=$(_get_font_display_name "monaspace")
  [[ "$result" == "Monaspace Nerd Font" ]]
}

@test "_get_font_display_name returns original for unknown fonts" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVBASE_ROOT}/libs/font-registry.sh"
  source <(sed -n '/^_get_font_display_name()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  result=$(_get_font_display_name "unknown-font")
  [[ "$result" == "unknown-font" ]]
}

@test "install.sh avoids duplicate library sourcing" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "grep -q 'process-templates.sh' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_failure

  run bash -c "grep -q 'configure-shell.sh' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_failure
}

@test "install.sh defines phase helpers" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "grep -q 'run_preflight_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_configuration_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_installation_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success

  run bash -c "grep -q 'run_finalize_phase' '${DEVBASE_ROOT}/libs/install.sh'"
  assert_success
}

@test "run_configuration_phase fails on step error" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "
    source '${DEVBASE_ROOT}/libs/install-phases.sh'
    bootstrap_for_configuration() { return 1; }
    collect_user_configuration() { return 0; }
    display_configuration_summary() { return 0; }
    run_configuration_phase
  "

  assert_failure
}

@test "run_installation_phase stops progress on failure" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  run bash -c "
    source '${DEVBASE_ROOT}/libs/install-phases.sh'
    start_installation_progress() { :; }
    stop_installation_progress() { echo stopped; }
    show_phase() { :; }
    prepare_system() { return 1; }
    perform_installation() { return 0; }
    write_installation_summary() { return 0; }
    run_installation_phase
  "

  assert_failure
  assert_output --partial "stopped"
}

@test "validate_source_repository checks required directories" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."

  mkdir -p "${BATS_TEST_TMPDIR}/unrelated-cwd"
  cd "${BATS_TEST_TMPDIR}/unrelated-cwd"

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source <(sed -n '/^validate_source_repository()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  run validate_source_repository
  assert_success
}

@test "setup_installation_paths validates required variables" {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_TEMP="${BATS_TEST_TMPDIR}/devbase.test123"

  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source <(sed -n '/^setup_installation_paths()/,/^}/p' "${DEVBASE_ROOT}/libs/install.sh")

  run setup_installation_paths
  assert_success
}

# install.sh guards at source time, so extract just the function under test.
_load_npm_min_release_age() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  eval "$(awk '/^configure_npm_min_release_age\(\)/,/^}/' "${DEVBASE_ROOT}/libs/install.sh")"
  show_progress() { :; }
  add_install_warning() { :; }
}

# Stub npm so nothing here depends on the npm the host happens to have on PATH.
# $1 is what `npm config get` answers, $2 the exit code of `npm config set`.
# Every invocation is recorded so the tests can assert what devbase asked for.
_stub_npm() {
  local get_answer="$1" set_rc="${2:-0}"
  mkdir -p "${TEST_DIR}/bin"
  cat >"${TEST_DIR}/bin/npm" <<SCRIPT
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${TEST_DIR}/npm-calls"
[[ "\$1 \$2" == "config set" ]] && exit ${set_rc}
[[ "\$1 \$2" == "config get" ]] && printf '%s\n' "${get_answer}"
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/npm"
  : >"${TEST_DIR}/npm-calls"
  export PATH="${TEST_DIR}/bin:${PATH}"
}

@test "configure_npm_min_release_age skips when npm is not installed" {
  _load_npm_min_release_age
  mkdir -p "${TEST_DIR}/no-npm"
  local host_path="$PATH"

  PATH="${TEST_DIR}/no-npm" configure_npm_min_release_age
  local rc=$?
  PATH="$host_path"

  assert_equal "$rc" 0
}

@test "configure_npm_min_release_age sets the value at user scope when unset" {
  _load_npm_min_release_age
  _stub_npm "null"

  configure_npm_min_release_age

  # --location=user leaves the rest of the user's npmrc to npm.
  run cat "${TEST_DIR}/npm-calls"
  assert_success
  assert_output --partial "config set min-release-age=7 --location=user"
}

@test "configure_npm_min_release_age leaves an existing value alone" {
  _load_npm_min_release_age
  _stub_npm "30"

  configure_npm_min_release_age

  run cat "${TEST_DIR}/npm-calls"
  assert_success
  refute_output --partial "config set"
}

@test "configure_npm_min_release_age honours DEVBASE_NPM_MIN_RELEASE_AGE" {
  _load_npm_min_release_age
  _stub_npm "null"
  export DEVBASE_NPM_MIN_RELEASE_AGE=14

  configure_npm_min_release_age

  run cat "${TEST_DIR}/npm-calls"
  assert_success
  assert_output --partial "config set min-release-age=14 --location=user"
}

@test "configure_npm_min_release_age warns rather than fails when npm rejects the write" {
  _load_npm_min_release_age
  _stub_npm "null" 1
  add_install_warning() { printf '%s\n' "$1" >>"${TEST_DIR}/warnings"; }

  run configure_npm_min_release_age
  assert_success

  run cat "${TEST_DIR}/warnings"
  assert_output --partial "Could not set npm min-release-age"
}

_load_report_sudoers_failure() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  eval "$(awk '/^_report_sudoers_failure\(\)/,/^}/' "${DEVBASE_ROOT}/libs/install.sh")"
  show_progress() { printf '%s %s\n' "$1" "$2"; }
  # Stub sudo so the test does not depend on it being installed or authorised
  sudo() { [[ "$1" == "--version" ]] && printf 'Sudo version 1.9.15p5\n'; }
}

@test "_report_sudoers_failure surfaces visudo diagnostics" {
  _load_report_sudoers_failure

  run _report_sudoers_failure "Invalid sudoers proxy config" \
    "/tmp/x:1:21: syntax error
Defaults env_keep +="

  assert_success
  assert_output --partial "Invalid sudoers proxy config"
  assert_output --partial "visudo: /tmp/x:1:21: syntax error"
  assert_output --partial "visudo: Defaults env_keep +="
}

@test "_report_sudoers_failure names the sudo implementation" {
  _load_report_sudoers_failure

  run _report_sudoers_failure "Invalid sudoers proxy config" "some error"

  assert_success
  assert_output --partial "using: Sudo version 1.9.15p5"
}

@test "_report_sudoers_failure says so when visudo produced no output" {
  _load_report_sudoers_failure

  run _report_sudoers_failure "Invalid sudoers proxy config" ""

  assert_success
  assert_output --partial "visudo exited non-zero without output"
}

# setup_sudo_and_system validates a sudoers fragment, installs it 0440, then
# re-validates and rolls back if the installed copy is rejected.

_sudoers_harness() {
  local visudo_rc="$1"       # exit code the stubbed visudo returns
  local second_visudo_rc="${2:-0}"
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/sudo" << SCRIPT
#!/usr/bin/env bash
echo "\$*" >> "${TEST_DIR}/sudo.log"
case "\$1" in
  visudo)
    # -c -f <file>; the destination check is the second invocation
    if grep -qc 'install' "${TEST_DIR}/sudo.log" 2>/dev/null && [[ "\$4" == */etc/* ]]; then
      exit ${second_visudo_rc}
    fi
    exit ${visudo_rc}
    ;;
  install)
    # \$2=-m \$3=mode \$4=src \$5=dst - redirect the destination
    cp "\$4" "${TEST_DIR}/installed-sudoers"
    echo "\$3" > "${TEST_DIR}/installed-mode"
    exit 0
    ;;
  rm) rm -f "${TEST_DIR}/installed-sudoers"; exit 0 ;;
esac
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo"
}

_run_setup_sudo() {
  run --separate-stderr bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_FILES='${DEVBASE_ROOT}/devbase_files'
    export DEVBASE_PROXY_HOST='proxy.example.com'
    export DEVBASE_PROXY_PORT='8080'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    eval \"\$(awk '/^_report_sudoers_failure\(\)/,/^}/' '${DEVBASE_ROOT}/libs/install.sh')\"
    eval \"\$(awk '/^setup_sudo_and_system\(\)/,/^}/' '${DEVBASE_ROOT}/libs/install.sh')\"
    setup_sudo_and_system
  "
}

@test "setup_sudo_and_system installs the sudoers fragment mode 0440" {
  _sudoers_harness 0 0
  _run_setup_sudo

  assert_success
  assert_equal "$(cat "${TEST_DIR}/installed-mode")" "0440"
}

@test "setup_sudo_and_system refuses to install a fragment visudo rejects" {
  _sudoers_harness 1
  _run_setup_sudo

  assert_failure
  assert [ ! -f "${TEST_DIR}/installed-sudoers" ]
  run grep -c install "${TEST_DIR}/sudo.log"
  assert_output "0"
}

@test "setup_sudo_and_system removes the fragment when the installed copy is rejected" {
  _sudoers_harness 0 1
  _run_setup_sudo

  assert_failure
  assert [ ! -f "${TEST_DIR}/installed-sudoers" ]
  run grep -c '^rm' "${TEST_DIR}/sudo.log"
  assert_output "1"
}
