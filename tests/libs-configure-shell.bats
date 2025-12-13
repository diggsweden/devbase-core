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
  # Alias for backward compatibility with tests using TEST_HOME
  TEST_HOME="$HOME"
  export TEST_HOME
  
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/fish" << 'SCRIPT'
#!/usr/bin/env bash
echo "/usr/bin/fish"
SCRIPT
  chmod +x "${TEST_DIR}/bin/fish"
  
  cat > "${TEST_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo"
}

teardown() {
  common_teardown
}

@test "configure_fish_interactive adds fish to /etc/shells when available" {
  touch "${TEST_HOME}/.bashrc"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Fish shell configured"
}

@test "configure_fish_interactive adds launch code to bashrc" {
  touch "${TEST_HOME}/.bashrc"
  
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  " >/dev/null 2>&1
  
  assert_file_exists "${TEST_HOME}/.bashrc"
  run grep -c "Launch Fish for interactive sessions" "${TEST_HOME}/.bashrc"
  assert_success
  assert_output "1"
}

@test "configure_fish_interactive skips when fish not found" {
  touch "${TEST_HOME}/.bashrc"
  
  mkdir -p "${TEST_DIR}/nofish"
  for cmd in cat grep tee chmod mkdir rm touch tr sed awk head tail wc; do
    ln -sf "/usr/bin/$cmd" "${TEST_DIR}/nofish/$cmd" 2>/dev/null || true
  done
  ln -sf /bin/bash "${TEST_DIR}/nofish/bash"
  
  cat > "${TEST_DIR}/nofish/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/nofish/sudo"
  
  run bash -c "
    export PATH='${TEST_DIR}/nofish'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Fish shell not found"
}

@test "configure_fish_interactive doesn't add duplicate launch code" {
  echo "# Launch Fish for interactive sessions (added by devbase)" > "${TEST_HOME}/.bashrc"
  echo "exec fish" >> "${TEST_HOME}/.bashrc"
  
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  " >/dev/null 2>&1
  
  run grep -c "Launch Fish for interactive sessions" "${TEST_HOME}/.bashrc"
  assert_output "1"
}

@test "configure_fish_interactive creates .bashrc if missing" {
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  " >/dev/null 2>&1
  
  assert_file_exists "${TEST_HOME}/.bashrc"
  run grep -q "Launch Fish for interactive sessions" "${TEST_HOME}/.bashrc"
  assert_success
}

@test "configure_fish_interactive checks for interactive shell correctly" {
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  " >/dev/null 2>&1
  
  run grep '\$- == \*i\*' "${TEST_HOME}/.bashrc"
  assert_success
}

@test "configure_fish_interactive uses exec to replace bash" {
  bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export HOME='${TEST_HOME}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  " >/dev/null 2>&1
  
  run grep 'exec fish' "${TEST_HOME}/.bashrc"
  assert_success
}

@test "configure_fish_interactive validates HOME variable" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    unset HOME
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-shell.sh' >/dev/null 2>&1
    
    configure_fish_interactive
  "
  
  assert_failure
}
