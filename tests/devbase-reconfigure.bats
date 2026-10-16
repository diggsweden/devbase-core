#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  export RECONFIGURE_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-reconfigure.fish"
}

teardown() {
  common_teardown
}

@test "devbase-reconfigure reruns setup interactively from the persisted core" {
  local core_dir="${HOME}/.local/share/devbase/core"
  mkdir -p "$core_dir"
  cat > "$core_dir/setup.sh" << 'SCRIPT'
#!/usr/bin/env bash
echo "setup args: $*"
pwd
SCRIPT
  chmod +x "$core_dir/setup.sh"

  run fish --no-config -c "set -gx HOME '$HOME'; source '$RECONFIGURE_FISH'; devbase-reconfigure --tui=whiptail"
  assert_success
  assert_line --index 0 "setup args: --tui=whiptail"
  refute_output --partial "keep-preferences"
  assert_output --partial "$core_dir"
}

@test "devbase-reconfigure fails clearly without a persisted core" {
  run fish --no-config -c "set -gx HOME '$HOME'; source '$RECONFIGURE_FISH'; devbase-reconfigure"
  assert_failure
  assert_output --partial "DevBase core not found"
}

@test "devbase-reconfigure --help explains the difference to devbase-update" {
  run fish --no-config -c "source '$RECONFIGURE_FISH'; devbase-reconfigure --help"
  assert_success
  assert_output --partial "devbase-update reuses them without asking"
}
