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

# Only basic system commands, so tools the host happens to have (CI runners
# ship gh, for example) never decide what these tests see.
_make_system_bin() {
  local dir="${TEST_DIR}/sysbin" cmd
  mkdir -p "$dir"
  for cmd in bash env cat cp mkdir mktemp mv rm ls sort grep sed head tr wc \
    dirname basename find id uname date chmod timeout sleep true false; do
    ln -sf "$(command -v "$cmd")" "$dir/$cmd"
  done
  printf '%s' "$dir"
}

setup() {
  common_setup_isolated
  mkdir -p "${XDG_CONFIG_HOME}/fish/completions"
  mkdir -p "${TEST_DIR}/bin"

  export ORIGINAL_PATH="$PATH"
  SYSTEM_BIN=$(_make_system_bin)
  export SYSTEM_BIN
  export PATH="${TEST_DIR}/bin:${SYSTEM_BIN}"
  export XDG_CACHE_HOME="${TEST_DIR}/cache"
  source_core_libs
  # run_mise_from_home_dir, used for the mise fallback, lives in utils.sh
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/configure-completions.sh"
}

teardown() {
  # The minimal PATH lives in TEST_DIR; bats still needs rm after cleanup
  export PATH="$ORIGINAL_PATH"
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

_mock_completion_tool() {
  # $1 = tool name, $2 = expected arguments, $3 = output
  cat > "${TEST_DIR}/bin/$1" << SCRIPT
#!/usr/bin/env bash
[[ "\$*" == "$2" ]] || { echo "unexpected arguments: \$*" >&2; exit 1; }
[[ -n "$3" ]] && printf '%s\n' "$3"
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/$1"
}

@test "configure_single_fish_completion passes each tool its own generator arguments" {
  _mock_completion_tool gh "completion -s fish" "# gh completion"
  _mock_completion_tool zellij "setup --generate-completion fish" "# zellij completion"
  _mock_completion_tool rg "--generate complete-fish" "# rg completion"
  _mock_completion_tool syft "completion fish" "# syft completion"

  for tool in gh zellij rg syft; do
    run --separate-stderr configure_single_fish_completion "$tool"
    assert_success
    run cat "${XDG_CONFIG_HOME}/fish/completions/${tool}.fish"
    assert_output "# ${tool} completion"
  done
}

@test "configure_single_fish_completion writes the just completion loader" {
  _mock_completion_tool just "--completions fish" "JUST_COMPLETE=fish just | source"

  run --separate-stderr configure_single_fish_completion just

  assert_success
  run cat "${XDG_CONFIG_HOME}/fish/completions/just.fish"
  assert_output "JUST_COMPLETE=fish just | source"
}

@test "configure_single_fish_completion keeps an existing file when the tool prints nothing" {
  _mock_completion_tool gh "completion -s fish" ""
  printf '%s\n' "# previous gh completion" > "${XDG_CONFIG_HOME}/fish/completions/gh.fish"

  run --separate-stderr configure_single_fish_completion gh

  assert_failure
  run cat "${XDG_CONFIG_HOME}/fish/completions/gh.fish"
  assert_output "# previous gh completion"
  run find "${XDG_CONFIG_HOME}/fish/completions" -name '.gh.*'
  assert_output ""
}

@test "configure_single_fish_completion creates the completion directory" {
  rm -rf "${XDG_CONFIG_HOME}/fish/completions"
  _mock_completion_tool kubectl "completion fish" "# kubectl completion"

  run --separate-stderr configure_single_fish_completion kubectl

  assert_success
  assert_file_exists "${XDG_CONFIG_HOME}/fish/completions/kubectl.fish"
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
    export PATH='${TEST_DIR}/bin:${SYSTEM_BIN}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_CONFIG_HOME='${TEST_DIR}/.config2'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/configure-completions.sh' >/dev/null 2>&1

    configure_fish_completions
    test -f '${fish_dir}/completions/kubectl.fish' && echo 'KUBECTL_EXISTS'
    test -e '${fish_dir}/completions/gh.fish' || echo 'GH_ABSENT'
  "

  assert_success
  assert_output --partial "KUBECTL_EXISTS"
  assert_output --partial "GH_ABSENT"
  # Other tools on the host PATH may be listed too; kubectl must be among them.
  assert_output --regexp "Shell completions configured \\([0-9]+ tools: .*kubectl"
}

@test "seed_tldr_cache updates the cache when tldr is installed" {
  cat > "${TEST_DIR}/bin/tldr" << 'SCRIPT'
#!/usr/bin/env bash
echo "tldr $*" >> "${TEST_DIR}/tldr.log"
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/tldr"

  run seed_tldr_cache
  assert_success
  assert_output --partial "tldr page cache seeded"
  run cat "${TEST_DIR}/tldr.log"
  assert_output "tldr --update --quiet"
}

@test "seed_tldr_cache is a no-op without tldr" {
  run seed_tldr_cache
  assert_success
  assert_output ""
}

@test "seed_tldr_cache reports a failed update" {
  cat > "${TEST_DIR}/bin/tldr" << 'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "${TEST_DIR}/bin/tldr"

  run seed_tldr_cache
  assert_failure
}

@test "configure_single_fish_completion finds mise tools that are not on PATH" {
  # The installer shell may lack the mise tool directories; `mise which` resolves them.
  mkdir -p "${TEST_DIR}/misebin"
  cat > "${TEST_DIR}/misebin/gh" << 'SCRIPT'
#!/usr/bin/env bash
[[ "$*" == "completion -s fish" ]] && echo "# gh completion from mise"
SCRIPT
  chmod +x "${TEST_DIR}/misebin/gh"
  cat > "${TEST_DIR}/bin/mise" << SCRIPT
#!/usr/bin/env bash
[[ "\$1 \$2" == "which gh" ]] && { echo "${TEST_DIR}/misebin/gh"; exit 0; }
exit 1
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  run --separate-stderr configure_single_fish_completion gh
  assert_success
  run cat "${XDG_CONFIG_HOME}/fish/completions/gh.fish"
  assert_output "# gh completion from mise"
}

@test "configure_single_fish_completion fails quietly for a known tool that is absent" {
  run --separate-stderr configure_single_fish_completion gh
  assert_failure
  assert_not_exists "${XDG_CONFIG_HOME}/fish/completions/gh.fish"
}

@test "seed_tldr_cache leaves an existing cache alone" {
  cat > "${TEST_DIR}/bin/tldr" << 'SCRIPT'
#!/usr/bin/env bash
echo "tldr $*" >> "${TEST_DIR}/tldr.log"
SCRIPT
  chmod +x "${TEST_DIR}/bin/tldr"
  mkdir -p "${XDG_CACHE_HOME}/tlrc/pages"

  run seed_tldr_cache
  assert_success
  assert_not_exists "${TEST_DIR}/tldr.log"
}
