#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2154

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  source "$DEVBASE_ROOT/libs/utils.sh"
  source "$DEVBASE_ROOT/libs/handle-network.sh"
  source "$DEVBASE_ROOT/libs/install-custom.sh"
  export _DEVBASE_TEMP="$TEST_DIR"
  TOOL_VERSIONS=([fisher]='4.4.8' [fzf_fish]='v11.0')
  export DEVBASE_GITHUB_CODELOAD_REGISTRY='https://registry.example/codeload'
  export FIXTURE="$TEST_DIR/archive" REQUEST_LOG="$TEST_DIR/requests"
  printf 'versioned source archive fixture\n' >"$FIXTURE"
  mkdir -p "$TEST_DIR/bin"
  cat >"$TEST_DIR/bin/curl" <<'SH'
#!/usr/bin/env bash
set -eu
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) cp "$FIXTURE" "$2"; shift 2 ;;
    https://*) printf '%s\n' "$1" >>"$REQUEST_LOG"; shift ;;
    *) shift ;;
  esac
done
printf '%s' "${FAKE_STATUS:-200}"
SH
  chmod +x "$TEST_DIR/bin/curl"
  export PATH="$TEST_DIR/bin:$PATH"
  unset DEVBASE_GITHUB_REGISTRY DEVBASE_GITHUB_RAW_REGISTRY DEVBASE_OPENSHIFT_REGISTRY FAKE_STATUS
}

teardown() { common_teardown; }

@test "Fisher child Fish downloads only the pinned mirrored archive" {
  local script='command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8'
  run _run_fisher --no-config -c 'command fish --no-config -c $argv[1] $argv[2]' "$script" "$TEST_DIR/download"
  assert_success
  assert_output 200
  assert_equal "$(cat "$REQUEST_LOG")" 'https://registry.example/codeload/jorgebucaran/fisher/tar.gz/refs/tags/4.4.8'
  run cmp "$FIXTURE" "$TEST_DIR/download"
  assert_success
  assert_equal "$(type -P curl)" "$TEST_DIR/bin/curl"
}

@test "fzf.fish uses its pinned codeload archive" {
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/patrickf1/fzf.fish/tarball/v11.0' "$TEST_DIR/download"
  assert_success
  assert_output 200
  assert_equal "$(cat "$REQUEST_LOG")" 'https://registry.example/codeload/PatrickF1/fzf.fish/tar.gz/refs/tags/v11.0'
}

@test "Fisher rejects failed archive downloads without an upstream fallback" {
  export FAKE_STATUS=404
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8' "$TEST_DIR/download"
  assert_failure
  assert_output --partial 'HTTP 404'
  assert_equal "$(wc -l <"$REQUEST_LOG")" 1
}

@test "Fisher rejects an empty archive even with HTTP 200" {
  : >"$FIXTURE"
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8' "$TEST_DIR/download"
  assert_failure
  assert_output --partial 'empty archive'
}

@test "Fisher refuses unconfigured plugins without contacting upstream" {
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/other/plugin/tarball/main' "$TEST_DIR/download"
  assert_failure
  assert_output --partial 'not configured for mirrored installation'
  assert_file_not_exists "$REQUEST_LOG"
}

@test "Fisher refuses floating versions before making a request" {
  TOOL_VERSIONS[fisher]=main
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/main' "$TEST_DIR/download"
  assert_failure
  assert_output --partial 'exact release version'
  assert_file_not_exists "$REQUEST_LOG"
}

@test "Fisher refuses redirects and has no upstream fallback" {
  export FAKE_STATUS=302
  run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8' "$TEST_DIR/download"
  assert_failure
  assert_output --partial 'HTTP 302'
  assert_equal "$(wc -l <"$REQUEST_LOG")" 1
}

@test "strict checksum policy without source exceptions blocks both Fisher downloads" {
  DEVBASE_STRICT_CHECKSUMS=fail
  DEVBASE_STRICT_CHECKSUMS_ALLOWLIST=''
  local url
  for url in \
    https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8 \
    https://api.github.com/repos/patrickf1/fzf.fish/tarball/v11.0; do
    run _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" $argv[2]' "$TEST_DIR/download" "$url"
    assert_failure
    assert_output --partial 'Checksum required for Fisher source'
    assert_file_not_exists "$REQUEST_LOG"
  done
}

@test "Fisher honours the existing warning policy without corrupting the HTTP status" {
  DEVBASE_STRICT_CHECKSUMS=warn
  DEVBASE_STRICT_CHECKSUMS_ALLOWLIST=''
  run --separate-stderr _run_fisher --no-config -c 'command curl -q --silent -L -o $argv[1] -w "%{http_code}" https://api.github.com/repos/jorgebucaran/fisher/tarball/4.4.8' "$TEST_DIR/download"
  assert_success
  assert_output 200
  [[ "$stderr" == *'WARNING: No checksum configured for Fisher source.'* ]]
}
