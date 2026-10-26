#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC1091,SC2016,SC2030,SC2031,SC2154,SC2329

bats_require_minimum_version 1.13.0
load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  DEVBASE_ROOT=$(realpath -e "$DEVBASE_ROOT")
  export DEVBASE_ROOT
  # The upstream pack deliberately permits /tmp writes. Place native-test homes
  # outside /tmp so the filesystem assertions exercise the normal home policy.
  if [[ "$BATS_TEST_DESCRIPTION" == native* && -n "${DEVBASE_TEST_NONO_BIN:-}" ]]; then
    common_teardown
    TEST_DIR=$(mktemp -d "$DEVBASE_ROOT/.opencode-test.XXXXXX")
    export TEST_DIR
    setup_isolated_home
  fi
  export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
  export XDG_BIN_HOME="$HOME/.local/bin" MISE_DATA_DIR="$XDG_DATA_HOME/mise"
  export DEVBASE_DOT="$DEVBASE_ROOT/dot" PACKAGES_YAML="$DEVBASE_ROOT/dot/.config/devbase/packages.yaml"
  export SELECTED_PACKS=ai
  unset _DEVBASE_CUSTOM_PACKAGES MISE_GLOBAL_CONFIG_FILE
  show_progress() { printf '%s\n' "$*"; }
  export -f show_progress
  source "$DEVBASE_LIBS/parse-packages.sh"
  source "$DEVBASE_LIBS/configure-opencode.sh"
  export ROOT="$XDG_DATA_HOME/devbase/opencode"
  export TEST_OPENCODE_DIR="$MISE_DATA_DIR/installs/opencode/1.19.4"
  export TEST_NONO_DIR="$MISE_DATA_DIR/installs/nono/0.80.0"
  mkdir -p "$TEST_DIR/bin" "$TEST_OPENCODE_DIR" "$TEST_NONO_DIR" "$HOME/project with spaces"
  cat >"$TEST_DIR/bin/mise" <<'EOF'
#!/bin/bash
[[ "$1" == --no-config && "$2" == where ]] || { printf 'unexpected lookup: %s\n' "$*" >&2; exit 90; }
case "$3" in
  aqua:anomalyco/opencode@v1.19.4) printf '%s\n' "$TEST_OPENCODE_DIR" ;;
  nono@0.80.0) printf '%s\n' "$TEST_NONO_DIR" ;;
  *) exit 91 ;;
esac
EOF
  cat >"$TEST_NONO_DIR/nono" <<'EOF'
#!/bin/bash
[[ -z "${NONO_ALLOW:-}${NONO_CAPABILITY_ELEVATION:-}" ]] || exit 92
if [[ "$1" == list ]]; then
  [[ -z "${TEST_PACK_MISSING:-}" ]] || exit 1
  printf '%s\n' '{"packages":{"nolabs-ai/opencode-v1":{"version":"0.1.0","pinned":true}}}'
  exit 0
fi
if [[ "$1" == pull ]]; then
  printf '%s\n' "$@" >"$TEST_DIR/pack-pull"
  exit "${TEST_PACK_EXIT:-0}"
fi
if [[ "$1" == pin ]]; then exit 0; fi
if [[ "$1" == profile ]]; then
  [[ -z "${TEST_PROFILE_FAIL:-}" ]] || exit 1
  [[ -z "${TEST_PROFILE_EMPTY:-}" ]] || exit 0
  if [[ -n "${TEST_PROFILE_INVALID:-}" ]]; then printf '{}\n'; exit 0; fi
  jq -n --arg path "${TEST_PACK_GRANT:-$HOME/.npm}" \
    '{filesystem:{grants:[{access:"readwrite",type:"directory",path:$path}]}}'
  exit 0
fi
printf '%s\0' "$@" >"$TEST_DIR/nono-args"
[[ -z "${TEST_NONO_FAIL:-}" ]] || exit 42
while [[ "$1" != -- ]]; do shift; done
shift
exec "$@"
EOF
  cat >"$TEST_OPENCODE_DIR/opencode" <<'EOF'
#!/bin/bash
printf '%s\0' "$@" >"$TEST_DIR/opencode-args"
printf '%s\n' "$PWD" "$OPENCODE_DISABLE_AUTOUPDATE"
exit "${TEST_OPENCODE_EXIT:-0}"
EOF
  chmod +x "$TEST_DIR/bin/mise" "$TEST_NONO_DIR/nono" "$TEST_OPENCODE_DIR/opencode"
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  if [[ "$TEST_DIR" == "$DEVBASE_ROOT"/.opencode-test.* ]]; then
    rm -rf -- "$TEST_DIR"
  else
    common_teardown
  fi
}

@test "AI selection generates a native mise wrapper and selecting another pack does not" {
  generate_mise_config "$TEST_DIR/config.toml"
  run yq -p=toml -o=yaml -r '.wrappers.opencode.command' "$TEST_DIR/config.toml"
  assert_success
  assert_output "$ROOT/launcher"
  run yq -p=toml -o=yaml -r '.tools."aqua:anomalyco/opencode"' "$TEST_DIR/config.toml"
  assert_success
  assert_output v1.19.4
  run yq -p=toml -o=yaml -r '.tools."aqua:openai/codex"' "$TEST_DIR/config.toml"
  assert_success
  assert_output 0.164.0
  SELECTED_PACKS=go
  generate_mise_config "$TEST_DIR/config.toml"
  run yq -p=toml -o=yaml -r '.wrappers.opencode // "absent"' "$TEST_DIR/config.toml"
  assert_output absent
  run yq -p=toml -o=yaml -r '.tools."aqua:openai/codex" // "absent"' "$TEST_DIR/config.toml"
  assert_success
  assert_output absent
}

@test "launcher installs idempotently and preserves user-owned entry points" {
  configure_opencode_launcher
  configure_opencode_launcher
  assert_link_exists "$XDG_BIN_HOME/opencode"
  rm "$XDG_BIN_HOME/opencode"
  printf 'personal\n' >"$XDG_BIN_HOME/opencode"
  run configure_opencode_launcher
  assert_failure
  run cat "$XDG_BIN_HOME/opencode"
  assert_output personal
}

@test "launcher forwards exact arguments through nono and preserves exit status and cwd" {
  configure_opencode_launcher
  export NONO_ALLOW=/ NONO_CAPABILITY_ELEVATION=true TEST_OPENCODE_EXIT=17
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode" run 'a b' '"quoted"' '--allow=/' ''
  assert_equal "$status" 17
  assert_output "$PWD"$'\ntrue'
  run python3 -c 'import os; from pathlib import Path; p=Path(os.environ["TEST_DIR"]); args=(p/"opencode-args").read_bytes().split(b"\0")[:-1]; assert args == [b"run",b"a b",b"\"quoted\"",b"--allow=/",b""]; n=(p/"nono-args").read_bytes().split(b"\0"); assert n[0] == b"run"; assert n[n.index(b"--")+2:n.index(b"--")+7] == args'
  assert_success
}

@test "missing nono and sandbox failures never run raw OpenCode" {
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  export TEST_NONO_FAIL=true
  run "$XDG_BIN_HOME/opencode" --version
  assert_equal "$status" 42
  assert_file_not_exists "$TEST_DIR/opencode-args"
  rm "$TEST_NONO_DIR/nono"
  run "$XDG_BIN_HOME/opencode" --version
  assert_failure
  assert_file_not_exists "$TEST_DIR/opencode-args"
}

@test "pack installation is version pinned and propagates conflicts without forcing" {
  configure_opencode_launcher
  install_nono_opencode_pack
  run cat "$TEST_DIR/pack-pull"
  assert_output $'pull\nnolabs-ai/opencode-v1@0.1.0\n--registry\nhttps://registry.nono.sh'
  export TEST_PACK_EXIT=1
  run install_nono_opencode_pack
  assert_failure
}

@test "AI setup fails before pulling the pack if either pinned executable is absent" {
  configure_opencode_launcher
  mv "$TEST_OPENCODE_DIR/opencode" "$TEST_OPENCODE_DIR/saved"
  run install_nono_opencode_pack
  assert_failure
  assert_output --partial 'requires both pinned OpenCode and nono'
  assert_file_not_exists "$TEST_DIR/pack-pull"
  mv "$TEST_OPENCODE_DIR/saved" "$TEST_OPENCODE_DIR/opencode"
  rm "$TEST_NONO_DIR/nono"
  run install_nono_opencode_pack
  assert_failure
  assert_file_not_exists "$TEST_DIR/pack-pull"
}

@test "missing pack prevents OpenCode from starting" {
  configure_opencode_launcher
  export TEST_PACK_MISSING=true
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'pack is missing or changed'
  assert_file_not_exists "$TEST_DIR/opencode-args"
}

@test "remote attachment and self-upgrade cannot bypass the managed runtime" {
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode" attach http://localhost:4096
  assert_failure
  run "$XDG_BIN_HOME/opencode" run --attach=http://localhost:4096 hello
  assert_failure
  run "$XDG_BIN_HOME/opencode" upgrade
  assert_failure
  run "$XDG_BIN_HOME/opencode" --log-level INFO attach http://localhost:4096
  assert_failure
  run "$XDG_BIN_HOME/opencode" --print-logs false --log-level=INFO upgrade
  assert_failure
  run "$XDG_BIN_HOME/opencode" --pure=true attach http://localhost:4096
  assert_failure
  run "$XDG_BIN_HOME/opencode" ./project attach http://localhost:4096
  assert_failure
  run "$XDG_BIN_HOME/opencode" --unknown-option ignored attach http://localhost:4096
  assert_failure
  run "$XDG_BIN_HOME/opencode" --log-level INFO run --attach http://localhost:4096 hello
  assert_failure
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "command-looking option values and prompt words are forwarded unchanged" {
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode" --prompt upgrade --model=attach
  assert_success
  run "$XDG_BIN_HOME/opencode" --log-level INFO run attach upgrade
  assert_success
  run python3 -c 'import os; from pathlib import Path; assert Path(os.environ["TEST_DIR"],"opencode-args").read_bytes() == b"--log-level\0INFO\0run\0attach\0upgrade\0"'
  assert_success
}

@test "mise native wrapper routes Bash Fish and mise exec through nono" {
  [[ -n "${DEVBASE_TEST_MISE_BIN:-}" ]] || skip 'Set DEVBASE_TEST_MISE_BIN for native wrapper dispatch validation'
  configure_opencode_launcher
  export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise" MISE_CACHE_DIR="$XDG_CACHE_HOME/mise" MISE_STATE_DIR="$XDG_STATE_HOME/mise"
  export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false
  mkdir -p "$MISE_CONFIG_DIR"
  printf '[wrappers.opencode]\ncommand = %s\n' "$(jq -nrc --arg p "$ROOT/launcher" '$p | tojson')" >"$MISE_CONFIG_DIR/config.toml"
  cd "$HOME/project with spaces"
  # Put an executable that would bypass nono on PATH: the wrapper must win.
  PATH="$(dirname "$DEVBASE_TEST_MISE_BIN"):$TEST_OPENCODE_DIR:$PATH"
  export PATH
  "$DEVBASE_TEST_MISE_BIN" reshim
  run "$DEVBASE_TEST_MISE_BIN" exec -- opencode --version
  assert_success
  assert_file_exists "$TEST_DIR/nono-args"
  rm "$TEST_DIR/nono-args"
  run bash --noprofile --norc -c 'eval "$("$DEVBASE_TEST_MISE_BIN" activate bash --shims)"; opencode --version'
  assert_success
  assert_file_exists "$TEST_DIR/nono-args"
  rm "$TEST_DIR/nono-args"
  run fish --no-config -c '"$DEVBASE_TEST_MISE_BIN" activate fish --shims | source; opencode --version'
  assert_success
  assert_file_exists "$TEST_DIR/nono-args"
}

@test "launcher refuses home and workspace overlap with its own policy" {
  configure_opencode_launcher
  cd "$HOME"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'project directory'
  cd "$XDG_DATA_HOME/devbase"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'overlaps managed tools'
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "linked runtime state cannot grant access to the installation" {
  configure_opencode_launcher
  ln -s "$XDG_DATA_HOME" "$XDG_DATA_HOME/opencode"
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'overlaps managed tools'
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "effective pack grants cannot write managed tools through a symlink or parent grant" {
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  ln -s "$MISE_DATA_DIR" "$HOME/.npm"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'Sandbox writable grant overlaps'
  rm "$HOME/.npm"
  export TEST_PACK_GRANT="$XDG_DATA_HOME"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'Sandbox writable grant overlaps'
  export TEST_PACK_GRANT="$ROOT/runtime.json"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "uninspectable upstream policy fails closed" {
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  export TEST_PROFILE_FAIL=true
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'Cannot inspect the effective nono filesystem policy'
  unset TEST_PROFILE_FAIL
  export TEST_PROFILE_INVALID=true
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "launcher-added runtime grants cannot cover a linked executable outside mise data" {
  configure_opencode_launcher
  export XDG_STATE_HOME="$HOME/custom-state"
  mkdir -p "$XDG_STATE_HOME/opencode"
  mv "$TEST_OPENCODE_DIR/opencode" "$XDG_STATE_HOME/opencode/opencode"
  ln -s "$XDG_STATE_HOME/opencode/opencode" "$TEST_OPENCODE_DIR/opencode"
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'writable grant overlaps'
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "successful but empty policy output fails closed" {
  configure_opencode_launcher
  export TEST_PROFILE_EMPTY=true
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'Cannot inspect the effective nono filesystem policy'
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "deselecting AI disables an existing fallback launcher" {
  configure_opencode_launcher
  SELECTED_PACKS=go
  configure_opencode_launcher
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'AI pack is not configured'
  assert_file_not_exists "$TEST_DIR/nono-args"
}

@test "native nono permits workspace writes but denies unrelated files and managed policy writes" {
  [[ -n "${DEVBASE_TEST_NONO_BIN:-}" ]] || skip 'Set DEVBASE_TEST_NONO_BIN to nono 0.80.0 for kernel enforcement validation'
  configure_opencode_launcher
  rm "$TEST_NONO_DIR/nono"
  cp "$DEVBASE_TEST_NONO_BIN" "$TEST_NONO_DIR/nono"
  install_nono_opencode_pack
  mkdir -p "$HOME/private"
  printf 'secret\n' >"$HOME/private/secret"
  cat >"$TEST_OPENCODE_DIR/opencode" <<'EOF'
#!/bin/bash
set -eu
printf 'ok\n' > workspace-result
if cat "$HOME/private/secret"; then exit 81; fi
if printf 'bad\n' >> "$XDG_DATA_HOME/devbase/opencode/runtime.json"; then exit 82; fi
if printf 'bad\n' > "$HOME/private/new-file"; then exit 83; fi
printf 'confinement verified\n'
EOF
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode"
  assert_success
  assert_output --partial 'confinement verified'
  assert_file_exists "$PWD/workspace-result"
  assert_file_not_exists "$HOME/private/new-file"
  # Exercise an inherited pack grant against real manifest expansion too.
  rm -rf "$HOME/.npm"
  ln -s "$MISE_DATA_DIR" "$HOME/.npm"
  run "$XDG_BIN_HOME/opencode"
  assert_failure
  assert_output --partial 'Sandbox writable grant overlaps'
}

@test "native OpenCode starts and loads configuration through the sandbox" {
  [[ -n "${DEVBASE_TEST_NONO_BIN:-}" && -n "${DEVBASE_TEST_OPENCODE_BIN:-}" ]] || skip 'Set DEVBASE_TEST_NONO_BIN and DEVBASE_TEST_OPENCODE_BIN for native startup validation'
  configure_opencode_launcher
  rm "$TEST_NONO_DIR/nono" "$TEST_OPENCODE_DIR/opencode"
  cp "$DEVBASE_TEST_NONO_BIN" "$TEST_NONO_DIR/nono"
  cp "$DEVBASE_TEST_OPENCODE_BIN" "$TEST_OPENCODE_DIR/opencode"
  install_nono_opencode_pack
  cd "$HOME/project with spaces"
  run "$XDG_BIN_HOME/opencode" --version
  assert_success
  assert_output --partial '1.19.0'
  run "$XDG_BIN_HOME/opencode" debug config
  assert_success
}
