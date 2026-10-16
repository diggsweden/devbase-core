#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'test_helper'

setup() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  command -v yq &>/dev/null || skip "yq not available"
}

@test "docs/tools-matrix.adoc is generated from the package manifest" {
  local generated="${BATS_TEST_TMPDIR}/tools-matrix.adoc"
  run "${DEVBASE_ROOT}/scripts/generate-tools-matrix.sh" "$generated"
  assert_success
  run diff -u "${DEVBASE_ROOT}/docs/tools-matrix.adoc" "$generated"
  assert_success
}

@test "every manifest entry carries a description" {
  run yq -r '
    [ (.core | to_entries[] | select(.key != "description") | .value | to_entries[]),
      (.packs[] | to_entries[] | select(.key != "description") | .value | to_entries[]) ]
    | map(select((.value | type) != "!!map" or (.value.description // "") == "")) | .[].key' \
    "${DEVBASE_ROOT}/dot/.config/devbase/packages.yaml"
  assert_success
  assert_output ""
}
