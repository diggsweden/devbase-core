#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC1091,SC2016,SC2030,SC2031,SC2153,SC2154

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  # Do not let activation state from the invoking shell restore its host PATH
  # or global config when a native Mise subprocess computes its environment.
  local name
  for name in ${!MISE_@} ${!__MISE_@}; do unset "$name"; done
  export DEVBASE_DOT="$DEVBASE_ROOT/dot"
  export PACKAGES_YAML="$DEVBASE_DOT/.config/devbase/packages.yaml"
  export SELECTED_PACKS=ai
  export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
  export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
  export MISE_CACHE_DIR="$HOME/.cache/mise"
  export MISE_STATE_DIR="$HOME/.local/state/mise"
  export MISE_OFFLINE=true MISE_AUTO_INSTALL=false
  unset PACKAGES_CUSTOM_YAML
  source "$DEVBASE_LIBS/parse-packages.sh"
}

teardown() {
  common_teardown
}

@test "AI config pins both agents and delegates each command to one sandbox owner" {
  generate_mise_config "$TEST_DIR/config.toml"
  run yq -p=toml -o=yaml -r '.tools."aqua:anomalyco/opencode", .tools."aqua:openai/codex", .tools.nono' "$TEST_DIR/config.toml"
  assert_success
  assert_output $'v1.19.4\n0.164.0\n0.80.0'
  local agent
  for agent in opencode codex; do
    run yq -p=toml -o=yaml -r ".wrappers.$agent.command, .wrappers.$agent.args[0]" "$TEST_DIR/config.toml"
    assert_success
    assert_output "$(printf 'nono-wrapper\n%s' "$agent")"
  done
  run get_custom_packages
  assert_success
  refute_output --partial 'nono_opencode_pack'

  SELECTED_PACKS=go
  generate_mise_config "$TEST_DIR/config.toml"
  run yq -p=toml -o=yaml -r '.wrappers // "absent"' "$TEST_DIR/config.toml"
  assert_success
  assert_output absent
}

@test "AI agents require the sandbox runtime in the generated tool set" {
  yq 'del(.packs.ai.mise.nono)' "$PACKAGES_YAML" >"$TEST_DIR/packages.yaml"
  PACKAGES_YAML="$TEST_DIR/packages.yaml"
  run generate_mise_config "$TEST_DIR/config.toml"
  assert_failure
  assert_output --partial 'requires the nono package'
}

@test "logical agent identity keeps delegation across registry names backends and options" {
  local opencode_backend
  for opencode_backend in null 'github:anomalyco/opencode' 'github:anomalyco/opencode[asset_pattern=opencode-linux-x64.tar.gz]'; do
    export TEST_OPENCODE_BACKEND="$opencode_backend"
    yq '.packs.ai.mise.opencode.backend = env(TEST_OPENCODE_BACKEND) |
        .packs.ai.mise.codex.backend = null |
        .packs.ai.mise.nono.backend = "github:nolabs-ai/nono"' \
      "$DEVBASE_DOT/.config/devbase/packages.yaml" >"$TEST_DIR/agents.yaml"
    PACKAGES_YAML="$TEST_DIR/agents.yaml"
    _MERGED_YAML=""
    generate_mise_config "$TEST_DIR/config.toml"
    run yq -p=toml -o=yaml -r '.wrappers.opencode.command, .wrappers.codex.command' "$TEST_DIR/config.toml"
    assert_success
    assert_output $'nono-wrapper\nnono-wrapper'
    if [[ "$opencode_backend" == null ]]; then
      run yq -p=toml -o=yaml -r '.tools.opencode, .tools.codex' "$TEST_DIR/config.toml"
      assert_success
      assert_output $'v1.19.4\n0.164.0'
    else
      run yq -p=toml -o=yaml -r ".tools.\"$opencode_backend\"" "$TEST_DIR/config.toml"
      assert_success
      assert_output v1.19.4
    fi
  done
}

@test "skipped logical agents do not get delegates and cannot bypass the runtime requirement" {
  yq '.packs.ai.mise.opencode.tags = ["@skip-wsl"]' "$PACKAGES_YAML" >"$TEST_DIR/skipped.yaml"
  PACKAGES_YAML="$TEST_DIR/skipped.yaml"
  is_wsl() { return 0; }
  generate_mise_config "$TEST_DIR/config.toml"
  run yq -p=toml -o=yaml -r '.wrappers.opencode // "absent"' "$TEST_DIR/config.toml"
  assert_success
  assert_output absent
  yq 'del(.packs.ai.mise.nono) | .packs.ai.mise.codex.backend = null' "$PACKAGES_YAML" >"$TEST_DIR/no-runtime.yaml"
  PACKAGES_YAML="$TEST_DIR/no-runtime.yaml"
  _MERGED_YAML=""
  run generate_mise_config "$TEST_DIR/config.toml"
  assert_failure
  assert_output --partial 'codex requires the nono package'
}

prepare_native_dispatch() {
  [[ -x "${DEVBASE_TEST_MISE_BIN:-}" ]] || skip 'Set DEVBASE_TEST_MISE_BIN for native Mise dispatch checks'
  mkdir -p "$MISE_CONFIG_DIR" "$TEST_DIR/bin" "$HOME/project" "$MISE_DATA_DIR/installs/node/24.1.0/bin"
  # Activation prepends Mise's own directory. Keep it inside this fixture so
  # it cannot select the host's installed nono-wrapper ahead of our delegate.
  cp "$DEVBASE_TEST_MISE_BIN" "$TEST_DIR/bin/mise"
  export DEVBASE_TEST_MISE_BIN="$TEST_DIR/bin/mise"
  generate_mise_config "$MISE_CONFIG_DIR/config.toml"
  # Keep the generated delegates, but use an offline core backend to supply
  # fake agent binaries. This tests lookup without downloading agent archives.
  yq -p=toml -o=toml '.tools = {"node": "24.1.0"}' "$MISE_CONFIG_DIR/config.toml" >"$TEST_DIR/native.toml"
  mv "$TEST_DIR/native.toml" "$MISE_CONFIG_DIR/config.toml"
  local agent
  for agent in opencode codex; do
    cat >"$MISE_DATA_DIR/installs/node/24.1.0/bin/$agent" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$TEST_DIR/raw-args"
printf 'RAW-AGENT\n'
SH
    chmod +x "$MISE_DATA_DIR/installs/node/24.1.0/bin/$agent"
  done
  cat >"$TEST_DIR/bin/nono-wrapper" <<'SH'
#!/bin/bash
printf '%s\0' "$@" >"$TEST_DIR/delegate-args"
agent=$1
shift
real=$("$DEVBASE_TEST_MISE_BIN" which "$agent") || exit
printf '%s\n' "$real" >"$TEST_DIR/selected-agent"
exec "$real" "$@"
SH
  chmod +x "$TEST_DIR/bin/nono-wrapper"
  export PATH="$TEST_DIR/bin:/usr/bin:/bin"
  "$DEVBASE_TEST_MISE_BIN" --cd "$HOME" trust "$MISE_CONFIG_DIR/config.toml"
  "$DEVBASE_TEST_MISE_BIN" --cd "$HOME" reshim
  cd "$HOME/project" || return 1
}

@test "native Mise delegates both agents with exact arguments and raw binary resolution" {
  prepare_native_dispatch
  local agent
  for agent in opencode codex; do
    run "$DEVBASE_TEST_MISE_BIN" exec -- bash -c 'command -v nono-wrapper'
    assert_success
    assert_output "$TEST_DIR/bin/nono-wrapper"
    run "$DEVBASE_TEST_MISE_BIN" exec -- "$agent" run 'a b' '"quoted"' '' --example
    assert_success
    assert_output RAW-AGENT
    local -a delegated=() raw=()
    mapfile -d '' -t delegated <"$TEST_DIR/delegate-args"
    mapfile -d '' -t raw <"$TEST_DIR/raw-args"
    assert_equal "${delegated[0]}" "$agent"
    assert_equal "${#delegated[@]}" 6
    assert_equal "${raw[0]}" run
    assert_equal "${raw[1]}" 'a b'
    assert_equal "${raw[2]}" '"quoted"'
    assert_equal "${raw[3]}" ''
    assert_equal "${raw[4]}" --example
    run test "$(<"$TEST_DIR/selected-agent")" = "$MISE_DATA_DIR/installs/node/24.1.0/bin/$agent"
    assert_success
  done
  run bash --noprofile --norc -c 'eval "$("$DEVBASE_TEST_MISE_BIN" activate bash --shims)"; opencode --version'
  assert_success
  assert_output RAW-AGENT
  if command -v fish >/dev/null; then
    run fish --no-config -c '"$DEVBASE_TEST_MISE_BIN" activate fish --shims | source; set -p fish_function_path "$DEVBASE_ROOT/dot/.config/fish/functions"; codex --version'
    assert_success
    assert_output RAW-AGENT
  fi
}

@test "native Mise refuses a missing delegate instead of launching the raw agent" {
  prepare_native_dispatch
  rm "$TEST_DIR/bin/nono-wrapper"
  local agent
  for agent in opencode codex; do
    run "$DEVBASE_TEST_MISE_BIN" exec -- "$agent" --version
    assert_failure
    refute_output --partial RAW-AGENT
    [[ ! -e "$TEST_DIR/raw-args" ]]
  done
}
