#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'

setup() {
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${BATS_TEST_DIRNAME}/../dot"
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  TEMP_DIR=$(temp_make)
  export TEMP_DIR
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/check-requirements.sh"
}

teardown() {
  temp_del "$TEMP_DIR"
  
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/snap" ]] && unstub snap || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/sudo" ]] && unstub sudo || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/uname" ]] && unstub uname || true
  fi
}

@test "load_snap_packages reads package list from default file" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEMP_DIR}/.config/devbase"
  cat > "${TEMP_DIR}/.config/devbase/snap-packages.txt" <<EOF
kubectl
helm --classic
terraform
EOF
  
  export DEVBASE_DOT="${TEMP_DIR}"
  
  load_snap_packages
  
  [[ ${#SNAP_PACKAGES[@]} -eq 3 ]]
  [[ "${SNAP_PACKAGES[0]}" == "kubectl" ]]
  [[ "${SNAP_PACKAGES[1]}" == "helm" ]]
  [[ "${SNAP_OPTIONS[1]}" == "--classic" ]]
}

@test "load_snap_packages skips comment lines" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEMP_DIR}/.config/devbase"
  cat > "${TEMP_DIR}/.config/devbase/snap-packages.txt" <<EOF
# This is a comment
kubectl
# Another comment
helm
EOF
  
  export DEVBASE_DOT="${TEMP_DIR}"
  
  load_snap_packages
  
  [[ ${#SNAP_PACKAGES[@]} -eq 2 ]]
  [[ "${SNAP_PACKAGES[0]}" == "kubectl" ]]
  [[ "${SNAP_PACKAGES[1]}" == "helm" ]]
}

@test "load_snap_packages skips empty lines" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEMP_DIR}/.config/devbase"
  cat > "${TEMP_DIR}/.config/devbase/snap-packages.txt" <<EOF
kubectl

helm

EOF
  
  export DEVBASE_DOT="${TEMP_DIR}"
  
  load_snap_packages
  
  [[ ${#SNAP_PACKAGES[@]} -eq 2 ]]
}

@test "load_snap_packages handles @skip-wsl tag in WSL environment" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEMP_DIR}/.config/devbase"
  cat > "${TEMP_DIR}/.config/devbase/snap-packages.txt" <<EOF
kubectl
snap-store # @skip-wsl
helm
EOF
  
  export DEVBASE_DOT="${TEMP_DIR}"
  export WSL_DISTRO_NAME="Ubuntu"
  
  load_snap_packages
  
  [[ ${#SNAP_PACKAGES[@]} -eq 2 ]]
  [[ "${SNAP_PACKAGES[0]}" == "kubectl" ]]
  [[ "${SNAP_PACKAGES[1]}" == "helm" ]]
}

@test "load_snap_packages uses custom package list when available" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  mkdir -p "${TEMP_DIR}/custom-packages"
  cat > "${TEMP_DIR}/custom-packages/snap-packages.txt" <<EOF
custom-tool
EOF
  
  export _DEVBASE_CUSTOM_PACKAGES="${TEMP_DIR}/custom-packages"
  export DEVBASE_DOT="${TEMP_DIR}"
  
  load_snap_packages
  
  [[ ${#SNAP_PACKAGES[@]} -eq 1 ]]
  [[ "${SNAP_PACKAGES[0]}" == "custom-tool" ]]
}

@test "configure_snap_proxy sets proxy when configured" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  export DEVBASE_PROXY_HOST="proxy.example.com"
  export DEVBASE_PROXY_PORT="8080"
  
  stub_repeated snap 'true'
  stub_repeated sudo 'snap * : true'
  
  run configure_snap_proxy
  assert_success
  
  unstub sudo
  unstub snap || true
}

@test "configure_snap_proxy does nothing when no proxy configured" {
  source "${DEVBASE_ROOT}/libs/install-snap.sh"
  
  unset DEVBASE_PROXY_HOST
  unset DEVBASE_PROXY_PORT
  
  run configure_snap_proxy
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
  
  PATH=""
  
  run snap_install "kubectl"
  assert_success
  assert_output --partial "snapd not installed"
}
