#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
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
  export DEVBASE_DOT="${TEST_DIR}/dot"
  source_core_libs_with_requirements
}

teardown() {
  # Unstub before deleting temp dir
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/snap" ]] && unstub snap || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/sudo" ]] && unstub sudo || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/uname" ]] && unstub uname || true
  fi
  
  common_teardown
}

@test "get_snap_packages reads packages from packages.yaml" {
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" <<EOF
core:
  snap:
    kubectl: {}
    helm: { options: "--classic" }
    terraform: {}
packs: {}
EOF
  
  export DEVBASE_DOT="${TEST_DIR}"
  export PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml"
  export SELECTED_PACKS=""
  
  run get_snap_packages
  
  assert_success
  assert_line --partial "kubectl|"
  assert_line --partial "helm|--classic"
  assert_line --partial "terraform|"
}

@test "get_snap_packages includes packages from selected packs" {
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" <<EOF
core:
  snap:
    kubectl: {}
packs:
  java:
    description: "Java development"
    snap:
      intellij-idea-ultimate: { options: "--classic" }
EOF
  
  export DEVBASE_DOT="${TEST_DIR}"
  export PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="java"
  
  run get_snap_packages
  
  assert_success
  # Should have kubectl (core) + intellij-idea-ultimate (java pack)
  [[ $(echo "$output" | wc -l) -eq 2 ]]
}

@test "get_snap_packages excludes unselected packs" {
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" <<EOF
core:
  snap:
    kubectl: {}
packs:
  java:
    description: "Java development"
    snap:
      intellij-idea-ultimate: { options: "--classic" }
  node:
    description: "Node development"
    snap:
      node-editor: {}
EOF
  
  export DEVBASE_DOT="${TEST_DIR}"
  export PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="java"
  
  run get_snap_packages
  
  assert_success
  # Should have kubectl (core) + intellij (java), NOT node-editor
  [[ $(echo "$output" | wc -l) -eq 2 ]]
  refute_output --partial "node-editor"
}

@test "get_snap_packages handles @skip-wsl tag in WSL environment" {
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" <<EOF
core:
  snap:
    kubectl: {}
    snap-store: { tags: ["@skip-wsl"] }
    helm: {}
packs: {}
EOF
  
  export DEVBASE_DOT="${TEST_DIR}"
  export PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml"
  export SELECTED_PACKS=""
  export WSL_DISTRO_NAME="Ubuntu"
  
  run get_snap_packages
  
  assert_success
  # Should have kubectl and helm, NOT snap-store
  [[ $(echo "$output" | wc -l) -eq 2 ]]
  refute_output --partial "snap-store"
}

@test "get_snap_packages merges custom packages.yaml overlay" {
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/custom-packages"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" <<EOF
core:
  snap:
    kubectl: {}
packs: {}
EOF

  cat > "${TEST_DIR}/custom-packages/packages-custom.yaml" <<EOF
core:
  snap:
    custom-tool: { options: "--classic" }
EOF
  
  export DEVBASE_DOT="${TEST_DIR}"
  export PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/custom-packages/packages-custom.yaml"
  export SELECTED_PACKS=""
  export _DEVBASE_CUSTOM_PACKAGES="${TEST_DIR}/custom-packages"
  
  run get_snap_packages
  
  assert_success
  assert_output --partial "custom-tool|--classic"
}

@test "configure_snap_proxy sets proxy when configured" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  export DEVBASE_PROXY_HOST="proxy.example.com"
  export DEVBASE_PROXY_PORT="8080"
  
  # Use test_helper's stub_repeated for commands that get called multiple times
  stub_repeated snap 'exit 0'
  stub_repeated sudo 'exit 0'
  
  run configure_snap_proxy
  assert_success
}

@test "configure_snap_proxy does nothing when no proxy configured" {
  run run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-snap.sh'
    configure_snap_proxy
  "
  assert_success
}

@test "snap_install returns success when snap already installed" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  stub snap 'list kubectl : true'
  
  run --separate-stderr snap_install "kubectl"
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}' stderr: '${stderr}'"
  assert_success
  assert_output --partial "already installed"
  
  unstub snap
}

@test "snap_install waits for auto-refresh to complete" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  stub snap 'list * : exit 1'
  stub sudo \
    'snap changes : echo "Done"' \
    'snap install * : true'
  
  run snap_install "kubectl"
  assert_success
  
  unstub snap
  unstub sudo
}

@test "snap_install handles package with options" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  stub snap 'list * : exit 1'
  stub sudo \
    'snap changes : echo "Done"' \
    'snap install * * : true'
  
  run snap_install "helm" "--classic"
  assert_success
  
  unstub snap
  unstub sudo
}

@test "snap_install fails gracefully when snapd not installed" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  # Create a subshell where snap command doesn't exist
  run bash -c "
    # Remove snap from PATH by creating empty PATH with only essential commands
    export PATH='${TEST_DIR}/bin'
    mkdir -p '${TEST_DIR}/bin'
    
    # Source required libs
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-snap.sh'
    
    snap_install 'kubectl'
  "
  
  assert_success
  assert_output --partial "snapd not installed"
}
