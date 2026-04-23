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
  mkdir -p "${TEST_DIR}/bin"
}

teardown() {
  common_teardown
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
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service 'test.service' 'Test Service'
  "
  
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
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service 'failing.service' 'Failing Service'
  "
  
  assert_failure
  assert_output --partial "Failed to enable"
}

@test "enable_user_service requires service name" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    enable_user_service ''
  "
  
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
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    set_system_limits
  "
  
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
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1
    
    configure_ufw
  "
  
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
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_service
  "

  assert_success
  assert_output --partial "Podman"
}

@test "configure_podman_compose_provider registers wrapper script when podman and shim exist" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  local shim_dir="${fake_home}/.local/share/mise/shims"
  mkdir -p "$shim_dir"
  cat > "${shim_dir}/docker-cli-plugin-docker-compose" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${shim_dir}/docker-cli-plugin-docker-compose"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  assert_output --partial "Registered docker-compose as Podman CLI plugin"
  local plugin_link="${fake_home}/.docker/cli-plugins/docker-compose"
  assert_file_exists "$plugin_link"
  assert_file_executable "$plugin_link"
  [ ! -L "$plugin_link" ]
  assert_file_contains "$plugin_link" "exec \"${fake_home}/.local/share/mise/shims/docker-cli-plugin-docker-compose\""
}

@test "configure_podman_compose_provider wrapper preserves argv[0] when executed" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  local shim_dir="${fake_home}/.local/share/mise/shims"
  mkdir -p "$shim_dir"
  # Fake shim prints its own invocation name — this is what mise inspects
  # to dispatch to the correct tool. If the wrapper is wrong, argv[0] leaks
  # through as "docker-compose" and mise errors out in the real world.
  cat > "${shim_dir}/docker-cli-plugin-docker-compose" << 'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$(basename "$0")"
SCRIPT
  chmod +x "${shim_dir}/docker-cli-plugin-docker-compose"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider >/dev/null
    '${fake_home}/.docker/cli-plugins/docker-compose'
  "

  assert_success
  assert_output --partial "docker-cli-plugin-docker-compose"
}

@test "configure_podman_compose_provider is idempotent (re-run replaces stale link)" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  local shim_dir="${fake_home}/.local/share/mise/shims"
  local plugin_dir="${fake_home}/.docker/cli-plugins"
  mkdir -p "$shim_dir" "$plugin_dir"
  cat > "${shim_dir}/docker-cli-plugin-docker-compose" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${shim_dir}/docker-cli-plugin-docker-compose"
  # Simulate a pre-existing broken install: a symlink to a dead target
  # (the original symlink-based implementation). The new wrapper must replace it.
  ln -sfn "/nonexistent/old-target" "${plugin_dir}/docker-compose"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  local plugin_link="${fake_home}/.docker/cli-plugins/docker-compose"
  assert_file_exists "$plugin_link"
  assert_file_executable "$plugin_link"
  [ ! -L "$plugin_link" ]
  assert_file_contains "$plugin_link" "exec \"${fake_home}/.local/share/mise/shims/docker-cli-plugin-docker-compose\""
}

@test "configure_podman_compose_provider skips when podman not installed" {
  local fake_home="${TEST_DIR}/home"
  mkdir -p "$fake_home"

  # PATH='/nonexistent' forces command -v podman to fail inside the isolated
  # shell, exercising the early-return branch even on systems where podman
  # lives in /usr/bin or /bin.
  run run_isolated "
    export HOME='${fake_home}'
    export PATH='/nonexistent'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  [ ! -e "${fake_home}/.docker/cli-plugins/docker-compose" ]
}

@test "configure_podman_compose_provider warns and skips when shim is missing" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  mkdir -p "$fake_home"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  assert_output --partial "docker-compose mise shim not found"
  [ ! -e "${fake_home}/.docker/cli-plugins/docker-compose" ]
}

@test "configure_podman_compose_provider removes stale wrapper when shim disappears" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  local plugin_dir="${fake_home}/.docker/cli-plugins"
  mkdir -p "$plugin_dir"
  # Simulate a leftover wrapper from a previous install where the compose
  # tool has since been removed from packages.yaml.
  cat > "${plugin_dir}/docker-compose" << 'SCRIPT'
#!/usr/bin/env bash
exec "/nonexistent/shim" "$@"
SCRIPT
  chmod +x "${plugin_dir}/docker-compose"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  assert_output --partial "docker-compose mise shim not found"
  [ ! -e "${plugin_dir}/docker-compose" ]
}

@test "configure_podman_compose_provider honours MISE_DATA_DIR" {
  cat > "${TEST_DIR}/bin/podman" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/podman"

  local fake_home="${TEST_DIR}/home"
  local custom_mise="${TEST_DIR}/custom-mise-data"
  local shim_dir="${custom_mise}/shims"
  mkdir -p "$shim_dir"
  cat > "${shim_dir}/docker-cli-plugin-docker-compose" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${shim_dir}/docker-cli-plugin-docker-compose"

  run run_isolated "
    export HOME='${fake_home}'
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export MISE_DATA_DIR='${custom_mise}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-services.sh' >/dev/null 2>&1

    configure_podman_compose_provider
  "

  assert_success
  local plugin_link="${fake_home}/.docker/cli-plugins/docker-compose"
  assert_file_exists "$plugin_link"
  assert_file_contains "$plugin_link" "exec \"${custom_mise}/shims/docker-cli-plugin-docker-compose\""
}
