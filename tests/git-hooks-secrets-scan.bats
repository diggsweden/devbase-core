#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Bats isolates each test; stub commands expand their variables when executed.
# shellcheck disable=SC2016,SC2030,SC2031

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'
load 'test_helper'

setup() {
  common_setup_isolated
  unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML
  mkdir -p "$TEST_DIR/repo with spaces/development/gitleaks"
  cd "$TEST_DIR/repo with spaces" || return 1
  printf '[extend]\nuseDefault = true\n' >development/gitleaks/gitleaks.toml
}

teardown() {
  if [[ -n "${GITLEAKS_STUB_PLAN:-}" ]]; then
    unstub gitleaks
  fi
  common_teardown
}

@test "secret hook discovers tool-owned configuration in the worktree" {
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config development/gitleaks/gitleaks.toml : exit 0'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_success
  assert_output --partial 'No secrets detected'
}

@test "secret hook selects root configuration before tool-owned configuration" {
  touch .gitleaks.toml
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config .gitleaks.toml : exit 0'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_success
}

@test "secret hook does not replace a broken root configuration symlink" {
  ln -s missing-config.toml .gitleaks.toml
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config .gitleaks.toml : exit 2'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_failure
}

@test "secret hook preserves explicit config path even when it does not exist" {
  export GITLEAKS_CONFIG="$TEST_DIR/missing policy.toml"
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner : test -n "$GITLEAKS_CONFIG"; exit 2'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_failure
}

@test "secret hook preserves inline config instead of selecting tool-owned config" {
  export GITLEAKS_CONFIG_TOML='[extend]
useDefault = true'
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner : test -n "$GITLEAKS_CONFIG_TOML"'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_success
}

@test "secret hook treats empty config environment values as unset" {
  export GITLEAKS_CONFIG='' GITLEAKS_CONFIG_TOML=''
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config development/gitleaks/gitleaks.toml : exit 0'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_success
}

@test "secret hook retains built-in defaults when no configuration exists" {
  rm development/gitleaks/gitleaks.toml
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner : exit 0'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_success
}

@test "secret hook blocks findings with tool-owned configuration" {
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config development/gitleaks/gitleaks.toml : exit 1'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_failure
  assert_output --partial 'Commit blocked'
}

@test "secret hook does not retry defaults after a tool-owned config error" {
  stub gitleaks 'git --pre-commit --staged --redact=100 --no-banner --config development/gitleaks/gitleaks.toml : exit 2'

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"

  assert_failure
  assert_output --partial 'Commit blocked'
}

@test "real scanner uses project rules and rejects dangling config paths" {
  command -v gitleaks
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  mkdir "$TEST_DIR/empty-templates"
  git init -q --template="$TEST_DIR/empty-templates"
  printf 'DEVBASE_TEST_MARKER\n' >fixture.txt
  git add fixture.txt
  cat >development/gitleaks/gitleaks.toml <<'TOML'
[[rules]]
id = "test-marker"
description = "Harmless configuration-selection marker"
regex = '''DEVBASE_TEST_MARKER'''
TOML

  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"
  assert_failure
  assert_output --partial 'leaks found: 1'

  # A valid root config takes precedence over the tool-owned marker rule.
  printf '[extend]\nuseDefault = true\n' >.gitleaks.toml
  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"
  assert_success

  rm .gitleaks.toml
  ln -s missing-config.toml .gitleaks.toml
  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"
  assert_failure
  assert_output --partial 'unable to load gitleaks config'

  # An explicit override still wins over an unusable discovered config.
  export GITLEAKS_CONFIG_TOML='[extend]
useDefault = true'
  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"
  assert_success
  unset GITLEAKS_CONFIG_TOML

  rm .gitleaks.toml development/gitleaks/gitleaks.toml
  ln -s missing-config.toml development/gitleaks/gitleaks.toml
  run bash "$DEVBASE_ROOT/devbase_files/git-hooks-templates/pre-commit.d/01-secrets-scan.sh"
  assert_failure
  assert_output --partial 'unable to load gitleaks config'
}
