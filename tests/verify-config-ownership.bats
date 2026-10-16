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
    [[ "$*" == "--cd $HOME list --current --json" ]] || return 1
    printf '%s\n' '{"aqua:tektoncd/cli":[{"version":"v0.46.1","installed":true}],"gitlab:gitlab-org/cli":[{"version":"v1.119.0","installed":false}]}'
  }
  run run_verification_check check_mise_tools
  assert_success
  assert_line --regexp 'aqua:tektoncd/cli .*effective: v0.46.1; DevBase default: v0.46.1'
  assert_line --regexp 'gitlab:gitlab-org/cli .*no installed effective version.*DevBase default: v1.119.0'
}

@test "mise verification counts structured and incomplete selections as failures" {
  mkdir -p "$(dirname "$MISE_CONFIG")"
  cat >"$MISE_CONFIG" <<'EOF'
[tools]
node = ["24.0.0", "26.0.0"]
[tools.rust]
version = "1.90.0"
components = "rust-analyzer"
EOF
  mise() {
    printf '%s\n' '{"node":[{"version":"24.0.0","installed":true},{"version":"26.0.0","installed":false}],"rust":[{"version":"1.90.0","installed":false}]}'
  }
  check_counts() {
    check_mise_tools
    printf 'counts=%s/%s failed=%s\n' "$MISE_INSTALLED_COUNT" "$MISE_TOTAL_COUNT" "$FAILED_CHECKS"
  }
  run run_verification_check check_counts
  assert_success
  assert_output --partial 'rust (no installed effective version'
  assert_output --partial 'counts=0/2 failed=2'
}

@test "Git diagnostics exclude sensitive values and URL subsection keys" {
  mkdir -p "$CONFIG_HOME/git"
  git config --file "$HOME/.gitconfig" user.name 'Fixture User'
  git config --file "$HOME/.gitconfig" http.extraHeader 'Authorization: Bearer fixture-header-secret'
  git config --file "$CONFIG_HOME/git/config" 'url.https://fixture-subsection-secret@example.test/.insteadOf' 'https://example.test/'
  git config --file "$CONFIG_HOME/git/config" http.proxy 'https://fixture-url-token@example.test/'
  run run_verification_check check_git_config
  assert_success
  assert_output --partial 'Fixture User'
  assert_output --partial 'https://***@example.test/'
  refute_output --partial fixture-header-secret
  refute_output --partial fixture-subsection-secret
  refute_output --partial fixture-url-token
}

@test "Git diagnostics show a value-less boolean key as true" {
  mkdir -p "$CONFIG_HOME/git"
  printf '[commit]\n\tgpgsign\n' >"$HOME/.gitconfig"
  run run_verification_check check_git_config
  assert_success
  assert_output --partial 'commit.gpgsign = true'
  refute_output --partial 'commit.gpgsign = commit.gpgsign'
}

@test "native mise reports missing structured runtimes and distinct backends to the verifier" {
  [[ -x "${DEVBASE_TEST_MISE_BIN:-}" ]] || skip 'Set DEVBASE_TEST_MISE_BIN for native validation'
  export MISE_DATA_DIR="$TEST_DIR/mise-data" MISE_CACHE_DIR="$TEST_DIR/mise-cache" MISE_STATE_DIR="$TEST_DIR/mise-state"
  export MISE_CONFIG_DIR="$CONFIG_HOME/mise" MISE_OFFLINE=true MISE_YES=1
  mkdir -p "$MISE_CONFIG_DIR"
  cat >"$MISE_CONFIG" <<'EOF'
[tools]
"aqua:tektoncd/cli" = "0.46.1"
"gitlab:gitlab-org/cli" = "1.119.0"
[tools.rust]
version = "1.90.0"
components = "rust-analyzer"
EOF
  "$DEVBASE_TEST_MISE_BIN" --cd "$HOME" trust "$MISE_CONFIG"
  mise() { "$DEVBASE_TEST_MISE_BIN" "$@"; }
  check_counts() {
    check_mise_tools
    printf 'counts=%s/%s failed=%s\n' "$MISE_INSTALLED_COUNT" "$MISE_TOTAL_COUNT" "$FAILED_CHECKS"
  }
  run run_verification_check check_counts
  assert_success
  assert_output --partial 'rust (no installed effective version'
  assert_output --partial 'aqua:tektoncd/cli (no installed effective version'
  assert_output --partial 'gitlab:gitlab-org/cli (no installed effective version'
  assert_output --partial 'counts=0/3 failed=3'
}

@test "diagnostics sanitize credentials before narrow and wide formatting" {
  printf '%s\n' 'https://fixture-token@example.test/' 'systemProp.http.proxyPassword=fixture-password' >"$TEST_DIR/settings"
  render_settings() {
    tput() { printf '%s\n' "$width"; }
    display_file_box "$TEST_DIR/settings"
    display_file_box "$TEST_DIR/settings" 54 '^[[:space:]]*#' true
    export FIXTURE_PROXY='https://fixture-user:fixture-long-password@example.test/'
    check_env_var FIXTURE_PROXY 24 true
  }
  local width
  for width in 30 120; do
    run run_verification_check render_settings
    assert_success
    refute_output --partial fixture-token
    refute_output --partial fixture-password
    refute_output --partial fixture-user
    refute_output --partial fixture-long-password
    assert_output --partial 'https://***@example.test/'
  done
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
