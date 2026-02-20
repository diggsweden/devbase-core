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
  mkdir -p "${XDG_CONFIG_HOME}/fish/completions"
  mkdir -p "${TEST_DIR}/bin"

  export PATH="${TEST_DIR}/bin:/usr/bin:/bin"
  source_core_libs
  source "${DEVBASE_ROOT}/libs/configure-completions.sh"
}

teardown() {
  common_teardown
}

@test "configure_single_fish_completion creates kubectl completion" {
  cat > "${TEST_DIR}/bin/kubectl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "completion" && "$2" == "fish" ]]; then
  echo "# kubectl completion"
fi
SCRIPT
  chmod +x "${TEST_DIR}/bin/kubectl"

  run --separate-stderr configure_single_fish_completion 'kubectl'

  assert_success
  run cat "${XDG_CONFIG_HOME}/fish/completions/kubectl.fish"
  assert_output "# kubectl completion"
}

@test "configure_single_fish_completion creates helm completion" {
  cat > "${TEST_DIR}/bin/helm" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "completion" && "$2" == "fish" ]]; then
  echo "# helm completion"
fi
SCRIPT
  chmod +x "${TEST_DIR}/bin/helm"

  configure_single_fish_completion 'helm' >/dev/null 2>&1

  assert_file_exists "${XDG_CONFIG_HOME}/fish/completions/helm.fish"
}

@test "configure_single_fish_completion requires tool name" {
  run --separate-stderr configure_single_fish_completion ''

  assert_failure
}

@test "configure_single_fish_completion handles unknown tool" {
  run --separate-stderr configure_single_fish_completion 'unknown_tool_xyz'

  # Should complete without error even for unknown tools
  assert_success
}

@test "configure_fish_completions creates completions for installed tools" {
  local fish_dir="${TEST_DIR}/.config2/fish"
  mkdir -p "${fish_dir}/completions"

  cat > "${TEST_DIR}/bin/fish" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/fish"

  cat > "${TEST_DIR}/bin/kubectl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "completion" && "$2" == "fish" ]]; then
  echo "# kubectl"
fi
SCRIPT
  chmod +x "${TEST_DIR}/bin/kubectl"

  run bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_CONFIG_HOME='${TEST_DIR}/.config2'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-completions.sh' >/dev/null 2>&1

    configure_fish_completions
    test -f '${fish_dir}/completions/kubectl.fish' && echo 'KUBECTL_EXISTS'
  "

  assert_success
  assert_output --partial "KUBECTL_EXISTS"
}
