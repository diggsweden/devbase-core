#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC2016,SC2030,SC2031,SC2153,SC2154

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  command -v fish >/dev/null || skip 'fish is required'
  common_setup_isolated
  export DEVBASE_FISH_FUNCTIONS="$DEVBASE_ROOT/dot/.config/fish/functions"
  mkdir -p "$TEST_DIR/bin"
  cat >"$TEST_DIR/bin/nono-wrapper" <<'SH'
#!/bin/sh
printf '%s\0' "$@" >"$TEST_DIR/delegated"
printf 'DELEGATED\n'
printf 'DELEGATE-STDERR\n' >&2
exit 23
SH
  local agent
  for agent in opencode codex; do
    cat >"$TEST_DIR/bin/$agent" <<'SH'
#!/bin/sh
printf 'RAW-AGENT\n'
exit 99
SH
  done
  chmod +x "$TEST_DIR/bin/nono-wrapper" "$TEST_DIR/bin/opencode" "$TEST_DIR/bin/codex"
  export PATH="$TEST_DIR/bin:/usr/bin:/bin"
}

teardown() {
  [[ -z "${TEST_DIR:-}" ]] || common_teardown
}

@test "Fish agent functions preserve exact arguments streams and delegate status" {
  local agent
  for agent in opencode codex; do
    export TEST_AGENT="$agent"
    run fish --no-config -c 'set -p fish_function_path "$DEVBASE_FISH_FUNCTIONS"; $TEST_AGENT --model "a b" "" "*" --help'
    assert_failure 23
    assert_output $'DELEGATED\nDELEGATE-STDERR'
    local -a args=()
    mapfile -d '' -t args <"$TEST_DIR/delegated"
    assert_equal "${#args[@]}" 6
    assert_equal "${args[0]}" "$agent"
    assert_equal "${args[1]}" --model
    assert_equal "${args[2]}" 'a b'
    assert_equal "${args[3]}" ''
    assert_equal "${args[4]}" '*'
    assert_equal "${args[5]}" --help
  done
}

@test "Fish dispatch uses the external nono-wrapper even if a function shadows it" {
  local agent
  for agent in opencode codex; do
    export TEST_AGENT="$agent"
    run fish --no-config -c 'set -p fish_function_path "$DEVBASE_FISH_FUNCTIONS"; function nono-wrapper; printf "SHADOWED\n"; return 99; end; $TEST_AGENT --version'
    assert_failure 23
    assert_output $'DELEGATED\nDELEGATE-STDERR'
  done
}

@test "Fish refuses a missing wrapper even when a raw agent is on PATH" {
  rm "$TEST_DIR/bin/nono-wrapper"
  local agent
  for agent in opencode codex; do
    export TEST_AGENT="$agent"
    run -127 fish --no-config -c 'set -p fish_function_path "$DEVBASE_FISH_FUNCTIONS"; $TEST_AGENT --version'
    assert_failure 127
    assert_output --partial 'nono-wrapper is required'
    refute_output --partial RAW-AGENT
    refute_output --partial unsandboxed
  done
}
