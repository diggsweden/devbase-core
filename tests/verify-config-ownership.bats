#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC2030,SC2031,SC2153,SC2329

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  CONFIG_HOME="$XDG_CONFIG_HOME"
  MISE_CONFIG="$CONFIG_HOME/mise/config.toml"
  unset STARSHIP_CONFIG
}

run_verification_check() {
  # The verifier is sourced directly; no system-wide checks should run.
  source "${DEVBASE_ROOT}/verify/verify-install-check.sh"
  # Record requested paths without checking unrelated tools on the test host.
  print_item_status() { printf '%s: %s\n' "${2:-file}" "$1"; }
  has_command() { return 1; }
  "$@"
}

teardown() {
  common_teardown
}

@test "verification accepts a personal Neovim config without DevBase plugin files" {
  mkdir -p "$CONFIG_HOME/nvim"
  echo '-- Personal setup' >"$CONFIG_HOME/nvim/init.lua"

  run run_verification_check check_user_directories
  assert_success
  refute_output --partial "$CONFIG_HOME/nvim/lua/plugins"
  run run_verification_check check_config_files
  assert_success
  refute_output --partial 'colorscheme.lua'
  run run_verification_check check_custom_tools
  assert_success
  assert_output --partial 'Personal Neovim configuration preserved'
}

@test "verification treats an unselected LazyVim starter as optional" {
  run run_verification_check check_custom_tools
  assert_success
  assert_output --partial 'LazyVim (optional, not installed)'
}

@test "verification checks the selected Starship file rather than the default seed" {
  export STARSHIP_CONFIG="$TEST_DIR/my-prompt.toml"
  touch "$STARSHIP_CONFIG"
  run run_verification_check check_config_files
  assert_success
  assert_output --partial "file: $STARSHIP_CONFIG"
  refute_output --partial "$CONFIG_HOME/starship/starship.toml"

  unset STARSHIP_CONFIG
  touch "$CONFIG_HOME/starship.toml"
  run run_verification_check check_config_files
  assert_success
  assert_output --partial "file: $CONFIG_HOME/starship.toml"
  refute_output --partial "$CONFIG_HOME/starship/starship.toml"

  rm "$CONFIG_HOME/starship.toml"
  run run_verification_check check_config_files
  assert_success
  assert_output --partial "file: $CONFIG_HOME/starship/starship.toml"
}

@test "verification retains distinct mise backend identities" {
  mkdir -p "$(dirname "$MISE_CONFIG")"
  cat >"$MISE_CONFIG" <<'EOF'
[tools]
"aqua:tektoncd/cli" = "v0.46.1"
"gitlab:gitlab-org/cli" = "v1.119.0"
EOF
  mise() {
    [[ "$*" == "--cd $HOME list --current --installed --no-header" ]] || return 1
    printf 'aqua:tektoncd/cli v0.46.1\n'
  }
  run run_verification_check check_mise_tools
  assert_success
  assert_line --regexp 'aqua:tektoncd/cli .*effective: v0.46.1; DevBase default: v0.46.1'
  assert_line --regexp 'gitlab:gitlab-org/cli .*no installed effective version; DevBase default: v1.119.0'
}

@test "verification expects the SSH config directory permissions set by installation" {
  export XDG_CONFIG_HOME="$TEST_DIR/custom-config"
  mkdir -p "$XDG_CONFIG_HOME/ssh"
  chmod 700 "$XDG_CONFIG_HOME/ssh"
  run run_verification_check check_security
  assert_success
  assert_output --partial "$XDG_CONFIG_HOME/ssh: 700"
  refute_output --partial 'expected 755'
}
