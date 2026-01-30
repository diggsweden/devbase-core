#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for devbase-vscode-extensions fish function

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  export DEVBASE_VSCODE_EXT_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-vscode-extensions.fish"
  
  # Create mock config directory (matching the fish function's expected paths)
  # Both preferences.yaml and packages.yaml live in ~/.config/devbase/
  export MOCK_CONFIG_DIR="${TEST_DIR}/.config/devbase"
  mkdir -p "$MOCK_CONFIG_DIR"
}

teardown() {
  common_teardown
}

# Helper to run fish commands with the devbase-vscode-extensions function loaded
run_fish_vscode_ext() {
  fish -c "source '$DEVBASE_VSCODE_EXT_FISH'; $*"
}

# Helper to run fish commands with HOME overridden to TEST_DIR
# Adds mise installs to PATH so yq is available (shims don't work without trusted mise config)
run_fish_vscode_ext_with_mock_home() {
  local yq_path
  yq_path=$(dirname "$(command -v yq)")
  env HOME="$TEST_DIR" PATH="${yq_path}:${PATH}" fish -c "source '$DEVBASE_VSCODE_EXT_FISH'; $*"
}

# Helper to create mock preferences.yaml
create_mock_preferences() {
  local packs="${1:-java node}"
  local vscode_neovim="${2:-false}"
  
  # Create properly formatted YAML with each pack on its own line
  {
    echo "packs:"
    for pack in $packs; do
      echo "  - $pack"
    done
    echo "vscode_neovim: $vscode_neovim"
  } > "${MOCK_CONFIG_DIR}/preferences.yaml"
}

# Helper to create mock packages.yaml
create_mock_packages() {
  cat > "${MOCK_CONFIG_DIR}/packages.yaml" <<EOF
core:
  vscode:
    redhat.vscode-yaml: {version: "1.0.0"}
    pkief.material-icon-theme: {version: "1.0.0"}
    asvetliakov.vscode-neovim: {version: "1.0.0", tags: ["@optional"]}
packs:
  java:
    vscode:
      redhat.java: {version: "1.0.0"}
      vscjava.vscode-java-pack: {version: "1.0.0"}
  node:
    vscode:
      dbaeumer.vscode-eslint: {version: "1.0.0"}
      esbenp.prettier-vscode: {version: "1.0.0"}
  python:
    description: "Python development"
EOF
}

@test "devbase-vscode-extensions.fish function file exists" {
  assert_file_exists "$DEVBASE_VSCODE_EXT_FISH"
}

@test "devbase-vscode-extensions --help shows usage" {
  run run_fish_vscode_ext "devbase-vscode-extensions --help"
  
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--list"
  assert_output --partial "--dry-run"
  assert_output --partial "VS Code extensions"
}

@test "devbase-vscode-extensions fails without yq" {
  # Skip if yq is not in PATH (can't test missing yq if it's installed)
  if command -v yq &>/dev/null; then
    skip "yq is installed, cannot test missing yq scenario"
  fi
  
  run run_fish_vscode_ext "devbase-vscode-extensions"
  
  assert_failure
  assert_output --partial "yq is required"
}

@test "devbase-vscode-extensions fails without preferences.yaml" {
  run fish -c "
    set -g __vscode_ext_preferences '${MOCK_CONFIG_DIR}/nonexistent.yaml'
    set -g __vscode_ext_packages_yaml '${MOCK_CONFIG_DIR}/packages.yaml'
    source '$DEVBASE_VSCODE_EXT_FISH'
    __vscode_ext_check_requirements
  "
  
  assert_failure
}

@test "__vscode_ext_get_selected_packs reads from preferences" {
  create_mock_preferences "java node python"
  
  run run_fish_vscode_ext_with_mock_home "__vscode_ext_get_selected_packs"
  
  assert_success
  assert_output --partial "java"
  assert_output --partial "node"
  assert_output --partial "python"
}

@test "__vscode_ext_prompt_neovim function exists" {
  # Verify the neovim prompt function exists (interactive, can't fully test)
  run run_fish_vscode_ext "type __vscode_ext_prompt_neovim"
  
  assert_success
  assert_output --partial "function"
}

@test "__vscode_ext_get_extensions returns core and pack extensions" {
  create_mock_packages
  
  run run_fish_vscode_ext_with_mock_home "__vscode_ext_get_extensions java node"
  
  assert_success
  # Core extensions
  assert_output --partial "redhat.vscode-yaml"
  assert_output --partial "pkief.material-icon-theme"
  # Java pack extensions
  assert_output --partial "redhat.java"
  assert_output --partial "vscjava.vscode-java-pack"
  # Node pack extensions
  assert_output --partial "dbaeumer.vscode-eslint"
  assert_output --partial "esbenp.prettier-vscode"
}

@test "__vscode_ext_get_extensions excludes unselected packs" {
  create_mock_packages
  
  # Only select java pack, not node
  run run_fish_vscode_ext_with_mock_home "__vscode_ext_get_extensions java"
  
  assert_success
  # Java pack extensions should be included
  assert_output --partial "redhat.java"
  # Node pack extensions should NOT be included
  refute_output --partial "dbaeumer.vscode-eslint"
  refute_output --partial "esbenp.prettier-vscode"
}

@test "__vscode_ext_display_name extracts extension name" {
  run run_fish_vscode_ext "__vscode_ext_display_name 'dbaeumer.vscode-eslint'"
  
  assert_success
  assert_output "vscode-eslint"
}

@test "__vscode_ext_is_optional_neovim identifies neovim extension" {
  run run_fish_vscode_ext "__vscode_ext_is_optional_neovim 'asvetliakov.vscode-neovim'"
  assert_success
  
  run run_fish_vscode_ext "__vscode_ext_is_optional_neovim 'redhat.java'"
  assert_failure
}

@test "devbase-vscode-extensions --list shows extensions by pack" {
  # Skip if VS Code is not installed (CI environment)
  if ! command -v code &>/dev/null; then
    skip "VS Code is not installed"
  fi

  create_mock_preferences "java node"
  create_mock_packages

  run run_fish_vscode_ext_with_mock_home "devbase-vscode-extensions --list"

  assert_success
  assert_output --partial "Core extensions:"
  assert_output --partial "java pack:"
  assert_output --partial "node pack:"
  assert_output --partial "redhat.vscode-yaml"
  assert_output --partial "redhat.java"
  assert_output --partial "dbaeumer.vscode-eslint"
}
