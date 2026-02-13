#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  source "${DEVBASE_ROOT}/libs/utils.sh"
}

teardown() {
  # Unstub before deleting temp dir
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/curl" ]] && unstub curl || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/jq" ]] && unstub jq || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/git" ]] && unstub git || true
  fi
  
  common_teardown
}

@test "get_vscode_checksum fetches checksum from API" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  stub curl '-fsSL * : echo "{\"products\":[{\"productVersion\":\"1.85.1\",\"platform\":{\"os\":\"linux-deb-x64\"},\"build\":\"stable\",\"sha256hash\":\"abc123\"}]}"'
  stub jq '-r * : echo "abc123"'
  
  run --separate-stderr get_vscode_checksum "1.85.1"
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  assert_success
  assert_output "abc123"
  
  unstub jq
  unstub curl
}

@test "get_vscode_checksum fails when jq not available" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  # Override command_exists to return false for jq
  command_exists() {
    [[ "$1" != "jq" ]]
  }
  
  run get_vscode_checksum "1.85.1"
  assert_failure
}

@test "get_vscode_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_vscode_checksum ""
  assert_failure
}

@test "get_oc_checksum fetches checksum from mirror" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  stub curl 'echo "abc123def456  openshift-client-linux-4.15.33.tar.gz"'
  
  result=$(get_oc_checksum "4.15.33")
  [[ "$result" == "abc123def456" ]]
  
  unstub curl
}

@test "get_oc_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_oc_checksum ""
  assert_failure
}

@test "install_lazyvim skips when user preference is false" {
  export DEVBASE_INSTALL_LAZYVIM="false"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""
  
  # Create minimal packages.yaml for parser
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    lazyvim: { version: "main", installer: "install_lazyvim" }
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run install_lazyvim
  assert_success
  assert_output --partial "skipped by user preference"
}

@test "install_lazyvim backs up existing nvim config" {
  export DEVBASE_INSTALL_LAZYVIM="true"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""
  
  # Create minimal packages.yaml for parser
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    lazyvim: { version: "main", installer: "install_lazyvim" }
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  # Create test template
  mkdir -p "${DEVBASE_DOT}/.config/nvim/lua/plugins"
  echo 'background=${THEME_BACKGROUND}' > "${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  mkdir -p "${XDG_CONFIG_HOME}/nvim"
  echo "existing config" > "${XDG_CONFIG_HOME}/nvim/init.lua"
  
  stub git \
    'clone * : mkdir -p "${XDG_CONFIG_HOME}/nvim/lua/plugins"'
  
  install_lazyvim
  
  run ls "${XDG_CONFIG_HOME}"/nvim.bak.*
  assert_success
  
  unstub git
}

@test "install_lazyvim configures light theme background" {
  export DEVBASE_INSTALL_LAZYVIM="true"
  export DEVBASE_THEME="everforest-light"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""
  
  # Create minimal packages.yaml for parser
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    lazyvim: { version: "main", installer: "install_lazyvim" }
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  stub git \
    'clone --quiet * : mkdir -p "$4/lua/plugins"'
  
  mkdir -p "${DEVBASE_DOT}/.config/nvim/lua/plugins"
  echo 'background=${THEME_BACKGROUND}' > "${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua.template"
  
  install_lazyvim
  
  [[ -f "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" ]]
  grep -q "background=light" "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua"
  
  unstub git
}

@test "_determine_font_details returns correct font info" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  result=$(_determine_font_details "monaspace")
  [[ "$result" =~ MonaspaceNerdFont ]]
  
  result=$(_determine_font_details "firacode")
  [[ "$result" =~ FiraCode ]]
}

@test "_is_wayland_session detects Wayland" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export WAYLAND_DISPLAY="wayland-0"
  
  run _is_wayland_session
  assert_success
  
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="wayland"
  
  run _is_wayland_session
  assert_success
}

@test "install_intellij_idea updates when version differs" {
  export DEVBASE_INSTALL_INTELLIJ="true"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export _DEVBASE_TEMP="${TEST_DIR}/tmp"

  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    intellij_idea: { version: "2025.3.2", installer: "install_intellij_idea" }
packs: {}
EOF

  mkdir -p "${HOME}/.local/share/JetBrains/IntelliJIdea"
  cat > "${HOME}/.local/share/JetBrains/IntelliJIdea/product-info.json" << 'EOF'
{
  "name": "IntelliJ IDEA",
  "version": "2025.2.0"
}
EOF

  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  _download_intellij_archive() { echo "${TEST_DIR}/fake.tar.gz"; }
  _extract_and_install_intellij() {
    local extract_dir="$2"
    mkdir -p "$extract_dir/IntelliJIdea"
    echo "$extract_dir/IntelliJIdea"
  }
  _configure_intellij_vmoptions() { :; }
  _create_intellij_desktop_file() { echo "$1" >"${TEST_DIR}/idea-desktop"; }

  run install_intellij_idea
  assert_success

  run ls "${HOME}/.local/share/JetBrains/IntelliJIdea-old"*
  assert_success
  assert_file_exists "${TEST_DIR}/idea-desktop"
}

@test "_is_wayland_session detects X11" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="x11"

  run _is_wayland_session
  assert_failure
}

@test "_configure_intellij_vmoptions enables Wayland with shadow fix" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  export WAYLAND_DISPLAY="wayland-0"
  local template="${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"

  _configure_intellij_vmoptions "2025.2" "$template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  assert_output --partial "-Dawt.toolkit.name=WLToolkit"
  assert_output --partial "-Dsun.awt.wl.Shadow=false"
}

@test "_configure_intellij_vmoptions omits Wayland on X11" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="x11"
  local template="${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"

  _configure_intellij_vmoptions "2025.2" "$template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  refute_output --partial "WLToolkit"
  refute_output --partial "wl.Shadow"
}

@test "_configure_intellij_vmoptions works without template" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  export WAYLAND_DISPLAY="wayland-0"

  _configure_intellij_vmoptions "2025.2" "/nonexistent/template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  assert_output --partial "-Dawt.toolkit.name=WLToolkit"
  assert_output --partial "-Dsun.awt.wl.Shadow=false"
}
