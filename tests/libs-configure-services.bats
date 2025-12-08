#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  
  mkdir -p "${TEST_DIR}/bin"
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "enable_user_service calls systemctl with correct parameters" {
  cat > "${TEST_DIR}/bin/systemctl" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/systemctl"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service 'test.service' 'Test Service'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Test Service enabled and started"
}

@test "enable_user_service handles enable failure" {
  cat > "${TEST_DIR}/bin/systemctl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$2" == "enable" ]]; then
  exit 1
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/systemctl"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service 'failing.service' 'Failing Service'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_failure
  assert_output --partial "Failed to enable"
}

@test "enable_user_service requires service name" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service ''
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_failure
}

@test "set_system_limits creates limits configuration" {
  local limits_content=""
  local sysctl_content=""
  
  cat > "${TEST_DIR}/bin/sudo" << SCRIPT
#!/usr/bin/env bash
if [[ "\$1" == "tee" ]]; then
  cat > "${TEST_DIR}/\$(basename "\$2")"
elif [[ "\$1" == "bash" && "\$2" == "-c" ]]; then
  eval "\$3"
elif [[ "\$1" == "sysctl" ]]; then
  exit 0
fi
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    set_system_limits
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "System limits configured"
  
  assert_file_exists "${TEST_DIR}/99-devbase.conf"
  run grep "nofile" "${TEST_DIR}/99-devbase.conf"
  assert_success
}

@test "configure_ufw enables firewall when ufw available" {
  cat > "${TEST_DIR}/bin/ufw" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/ufw"
  
  cat > "${TEST_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
"$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/sudo"
  
  cat > "${TEST_DIR}/bin/grep" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-qi" && "$2" == "microsoft" ]]; then
  exit 1
fi
/usr/bin/grep "$@"
SCRIPT
  chmod +x "${TEST_DIR}/bin/grep"
  
  mkdir -p "${TEST_DIR}/proc"
  echo "Linux" > "${TEST_DIR}/proc/version"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    configure_ufw
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "UFW firewall enabled"
}

@test "configure_podman_service enables podman socket" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"
  
  cat > "${TEST_DIR}/bin/systemctl" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/systemctl"
  
  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    configure_podman_service
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "Podman"
}
