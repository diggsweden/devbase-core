#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  export XDG_BIN_HOME="${HOME}/.local/bin"
  export XDG_CACHE_HOME="${HOME}/.cache"
  export XDG_STATE_HOME="${HOME}/.local/state"
  export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
  export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"
  export MISE_STATE_DIR="${XDG_STATE_HOME}/mise"
  export MISE_CONFIG_DIR="${XDG_CONFIG_HOME}/mise"
  unset MISE_GLOBAL_CONFIG_FILE _DEVBASE_BOOTSTRAP_BINS
  mkdir -p "${XDG_BIN_HOME}"
}

teardown() {
  common_teardown
}

@test "get_mise_packages parses packages.yaml" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  mise:
    just: { backend: "aqua:casey/just", version: "1.44.0" }
    fzf: { backend: "aqua:junegunn/fzf", version: "v0.67.0" }
packs: {}
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${TEST_DIR}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${TEST_DIR}/.config/devbase/packages.yaml'
    export SELECTED_PACKS=''
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    get_mise_packages
  "
  
  assert_success
  assert_output --partial "aqua:casey/just|1.44.0"
  assert_output --partial "aqua:junegunn/fzf|v0.67.0"
}

@test "get_mise_packages includes packages from selected packs" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  mise:
    just: { version: "1.44.0" }
packs:
  java:
    description: "Java development"
    mise:
      java: { version: "temurin-21" }
      maven: { version: "3.9.6" }
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${TEST_DIR}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${TEST_DIR}/.config/devbase/packages.yaml'
    export SELECTED_PACKS='java'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    get_mise_packages | wc -l
  "
  
  assert_success
  assert_output "3"
}

@test "get_tool_version returns version from packages.yaml" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: { version: "v2025.9.20", installer: "install_mise" }
packs: {}
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${TEST_DIR}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${TEST_DIR}/.config/devbase/packages.yaml'
    export SELECTED_PACKS=''
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    get_tool_version 'mise'
  "
  
  assert_success
  assert_output "v2025.9.20"
}

@test "generate_mise_config creates valid config.toml" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/mise"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  mise:
    just: { backend: "aqua:casey/just", version: "1.44.0" }
    fzf: { backend: "aqua:junegunn/fzf", version: "v0.67.0" }
packs:
  node:
    description: "Node.js"
    mise:
      node: { version: "24.11.1" }
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${TEST_DIR}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${TEST_DIR}/.config/devbase/packages.yaml'
    export SELECTED_PACKS='node'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    generate_mise_config '${TEST_DIR}/mise/config.toml'
    cat '${TEST_DIR}/mise/config.toml'
  "
  
  assert_success
  assert_output --partial '[tools]'
  assert_output --partial 'aqua:casey/just'
  assert_output --partial 'node = "24.11.1"'
}

@test "generate_mise_config uses packages.yaml as tool source" {
  mkdir -p "${TEST_DIR}/mise"
  mkdir -p "${TEST_DIR}/dot/.config/mise"

  cat > "${TEST_DIR}/dot/.config/mise/config.toml" << 'EOF'
[settings]
experimental = true

[env]
HTTP_PROXY = "{{ get_env(name='HTTP_PROXY', default='') }}"

[tools]
fake-tool = "9.9.9"
EOF

  run env \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}/dot" \
    DEVBASE_LIBS="${DEVBASE_ROOT}/libs" \
    PACKAGES_YAML="${DEVBASE_ROOT}/dot/.config/devbase/packages.yaml" \
    SELECTED_PACKS="java node" \
    TEST_DIR="${TEST_DIR}" \
    bash -c '
      source "$DEVBASE_LIBS/parse-packages.sh"

      output_file="$TEST_DIR/mise/config.toml"
      generate_mise_config "$output_file"

      just_backend=$(yq -r ".core.mise.just.backend" "$PACKAGES_YAML")
      just_version=$(yq -r ".core.mise.just.version" "$PACKAGES_YAML")

      grep -q "^\"${just_backend}\" = \"${just_version}\"$" "$output_file" || exit 1
      grep -q "^fake-tool =" "$output_file" && exit 1

      echo "OK"
    '

  assert_success
  assert_output --partial 'OK'
}

@test "generate_mise_config includes all mise tools from packages.yaml" {
  mkdir -p "${TEST_DIR}/mise"

  run env \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${DEVBASE_ROOT}/dot" \
    DEVBASE_LIBS="${DEVBASE_ROOT}/libs" \
    PACKAGES_YAML="${DEVBASE_ROOT}/dot/.config/devbase/packages.yaml" \
    SELECTED_PACKS="java node" \
    TEST_DIR="${TEST_DIR}" \
    bash -c '
      source "$DEVBASE_LIBS/parse-packages.sh"

      output_file="$TEST_DIR/mise/config.toml"
      generate_mise_config "$output_file"

      missing=0
      while IFS="|" read -r tool_key version; do
        [[ -z "$tool_key" || -z "$version" ]] && continue
        if [[ "$tool_key" == *:* || "$tool_key" == *[* ]]; then
          line="\"${tool_key}\" = \"${version}\""
        else
          line="${tool_key} = \"${version}\""
        fi

        if ! grep -q "^${line}$" "$output_file"; then
          echo "MISSING: ${line}" >&2
          missing=1
        fi
      done < <(get_mise_packages)

      [[ $missing -eq 0 ]]
    '

  assert_success
}

@test "get_core_runtimes returns runtimes based on selected packs" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core: {}
packs:
  node:
    description: "Node.js"
  java:
    description: "Java"
  python:
    description: "Python"
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${TEST_DIR}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${TEST_DIR}/.config/devbase/packages.yaml'
    export SELECTED_PACKS='node java'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    get_core_runtimes
  "
  
  assert_success
  assert_output --partial "node"
  assert_output --partial "java"
  refute_output --partial "python"
}

@test "_get_mise_target_version reads packages.yaml without yq when get_tool_version is unavailable" {
  # First-run bootstrap regression: install_mise runs before parse-packages.sh
  # (and therefore yq) is loaded. _get_mise_target_version must still resolve
  # the pinned version from packages.yaml — otherwise _run_mise_installer dies
  # with "Cannot determine mise version".
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: {version: "v2026.4.24", installer: "install_mise"}
packs: {}
EOF

  run env -i \
    PATH="/usr/bin:/bin" \
    HOME="${HOME}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    XDG_BIN_HOME="${XDG_BIN_HOME}" \
    bash -c '
      source "${DEVBASE_ROOT}/libs/install-mise.sh" >/dev/null 2>&1
      # Confirm parse-packages contract is NOT in scope (no get_tool_version)
      declare -f get_tool_version >/dev/null 2>&1 && { echo "UNEXPECTED: get_tool_version is loaded"; exit 99; }
      _get_mise_target_version
    '

  assert_success
  assert_output "2026.4.24"
}

# generate_mise_config repins yq to the packages.yaml version, which is not
# installed until the full run. mise env then emits no path for yq at all, so
# without this the bootstrap binary on disk becomes unreachable and package
# parsing fails mid-install.
@test "_mise_apply_path_from_activate keeps bootstrapped tools reachable" {
  mkdir -p "${TEST_DIR}/bin" "${TEST_DIR}/bootstrap"
  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
printf "export PATH='/usr/bin:/bin'\n"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  run bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    _DEVBASE_BOOTSTRAP_BINS='${TEST_DIR}/bootstrap'
    _mise_apply_path_from_activate '${TEST_DIR}/bin/mise'
    printf '%s' \"\$PATH\"
  "

  assert_success
  # First, so a stale pin in the generated config cannot shadow it.
  assert_output "${TEST_DIR}/bootstrap:/usr/bin:/bin"
}

@test "_mise_apply_path_from_activate leaves PATH to mise when nothing was bootstrapped" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
printf "export PATH='/usr/bin:/bin'\n"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  run bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    unset _DEVBASE_BOOTSTRAP_BINS
    _mise_apply_path_from_activate '${TEST_DIR}/bin/mise'
    printf '%s' \"\$PATH\"
  "

  assert_success
  assert_output "/usr/bin:/bin"
}

@test "_mise_remember_bootstrap_bin records the directory holding the binary" {
  mkdir -p "${TEST_DIR}/bin" "${TEST_DIR}/installs/yq/v4.52.4"
  touch "${TEST_DIR}/installs/yq/v4.52.4/yq"
  cat > "${TEST_DIR}/bin/mise" << SCRIPT
#!/usr/bin/env bash
[[ "\$*" == "--no-config which yq --tool aqua:mikefarah/yq@v4.52.4" ]] && printf '%s\n' "${TEST_DIR}/installs/yq/v4.52.4/yq"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  run bash -c "
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    _mise_remember_bootstrap_bin yq '${TEST_DIR}/bin/mise' aqua:mikefarah/yq@v4.52.4
    # A second call must not stack the same directory twice.
    _mise_remember_bootstrap_bin yq '${TEST_DIR}/bin/mise' aqua:mikefarah/yq@v4.52.4
    printf '%s' \"\$_DEVBASE_BOOTSTRAP_BINS\"
  "

  assert_success
  assert_output "${TEST_DIR}/installs/yq/v4.52.4"
}

@test "_mise_remember_bootstrap_bin records nothing when mise cannot resolve the tool" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  run bash -c "
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    _mise_remember_bootstrap_bin yq '${TEST_DIR}/bin/mise' aqua:mikefarah/yq@v4.52.4
    printf '[%s]' \"\${_DEVBASE_BOOTSTRAP_BINS:-}\"
  "

  assert_success
  assert_output "[]"
}

@test "_get_mise_target_version prefers packages-custom.yaml over base" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/custom/packages"

  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: {version: "v2026.4.24", installer: "install_mise"}
packs: {}
EOF

  cat > "${TEST_DIR}/custom/packages/packages-custom.yaml" << 'EOF'
core:
  custom:
    mise: {version: "v2026.5.0", installer: "install_mise"}
EOF

  run env -i \
    PATH="/usr/bin:/bin" \
    HOME="${HOME}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    XDG_BIN_HOME="${XDG_BIN_HOME}" \
    _DEVBASE_CUSTOM_PACKAGES="${TEST_DIR}/custom/packages" \
    bash -c '
      source "${DEVBASE_ROOT}/libs/install-mise.sh" >/dev/null 2>&1
      _get_mise_target_version
    '

  assert_success
  assert_output "2026.5.0"
}

@test "_get_mise_target_version falls back to base when custom yaml lacks mise" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/custom/packages"

  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: {version: "v2026.4.24", installer: "install_mise"}
packs: {}
EOF

  cat > "${TEST_DIR}/custom/packages/packages-custom.yaml" << 'EOF'
packs: {}
EOF

  run env -i \
    PATH="/usr/bin:/bin" \
    HOME="${HOME}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    XDG_BIN_HOME="${XDG_BIN_HOME}" \
    _DEVBASE_CUSTOM_PACKAGES="${TEST_DIR}/custom/packages" \
    bash -c '
      source "${DEVBASE_ROOT}/libs/install-mise.sh" >/dev/null 2>&1
      _get_mise_target_version
    '

  assert_success
  assert_output "2026.4.24"
}

@test "_get_mise_target_version returns 1 when packages.yaml has no mise pin" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom: {}
packs: {}
EOF

  run env -i \
    PATH="/usr/bin:/bin" \
    HOME="${HOME}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    XDG_BIN_HOME="${XDG_BIN_HOME}" \
    bash -c '
      source "${DEVBASE_ROOT}/libs/install-mise.sh" >/dev/null 2>&1
      _get_mise_target_version && echo "FOUND" || echo "NOT_FOUND"
    '

  assert_success
  assert_output "NOT_FOUND"
}

@test "_get_mise_target_version prefers MISE_VERSION env over packages.yaml" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: {version: "v2026.4.24", installer: "install_mise"}
packs: {}
EOF

  run env -i \
    PATH="/usr/bin:/bin" \
    HOME="${HOME}" \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    XDG_BIN_HOME="${XDG_BIN_HOME}" \
    MISE_VERSION="v2027.1.0" \
    bash -c '
      source "${DEVBASE_ROOT}/libs/install-mise.sh" >/dev/null 2>&1
      _get_mise_target_version
    '

  assert_success
  assert_output "2027.1.0"
}

@test "verify_mise_checksum returns 1 if mise binary doesn't exist" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_BIN_HOME='${XDG_BIN_HOME}'
    source '${DEVBASE_ROOT}/libs/constants.sh'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1

    verify_mise_checksum && echo 'EXISTS' || echo 'NOT_EXISTS'
  "
  
  assert_success
  assert_output "NOT_EXISTS"
}

@test "update_mise_if_needed reinstalls when version mismatches" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${TEST_DIR}/tmp"
  mkdir -p "${TEST_DIR}/fake-release/mise/bin"

  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: { version: "v2026.2.0", installer: "install_mise" }
packs: {}
EOF

  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
echo "mise v2026.1.0"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  # Build a fake release tarball with the same layout the upstream tarball has
  # (mise/bin/mise). The fake binary just echoes the version so we can verify
  # _run_mise_installer extracts and places it correctly.
  cat > "${TEST_DIR}/fake-release/mise/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
echo "mise v2026.2.0"
SCRIPT
  chmod +x "${TEST_DIR}/fake-release/mise/bin/mise"
  ( cd "${TEST_DIR}/fake-release" && tar -czf "${TEST_DIR}/fake-mise.tar.gz" mise )

  run env \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    DEVBASE_LIBS="${DEVBASE_ROOT}/libs" \
    PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml" \
    SELECTED_PACKS="" \
    _DEVBASE_TEMP="${TEST_DIR}/tmp" \
    PATH="${TEST_DIR}/bin:$PATH" \
    TEST_DIR="${TEST_DIR}" \
    HOME="${HOME}" \
    bash -c '
    cat > "${TEST_DIR}/mock-fns.sh" << "SCRIPT"
retry_command() {
  # Stub the SHASUMS download: write a synthetic line with the actual SHA of
  # our fake tarball and the asset name _run_mise_installer expects.
  local out_idx=$(($# - 1))
  local out_file="${@: -1}"
  local fake_sha
  fake_sha=$(sha256sum "${TEST_DIR}/fake-mise.tar.gz" | cut -d" " -f1)
  echo "${fake_sha}  ./mise-v2026.2.0-linux-x64.tar.gz" > "$out_file"
}
download_file() { cp "${TEST_DIR}/fake-mise.tar.gz" "$2"; }
verify_mise_checksum() { return 0; }
SCRIPT

    source "${DEVBASE_ROOT}/libs/constants.sh"
    source "${DEVBASE_ROOT}/libs/define-colors.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/validation.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/utils.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/parse-packages.sh"
    source "${DEVBASE_ROOT}/libs/install-mise.sh"
    source "${TEST_DIR}/mock-fns.sh"

    update_mise_if_needed
    "${XDG_BIN_HOME}/mise" --version
  '

  assert_success
  assert_output --partial "mise v2026.2.0"
}

@test "update_mise_if_needed skips downgrade when newer is installed" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/bin"
  mkdir -p "${HOME}/.local/bin"
  mkdir -p "${TEST_DIR}/tmp"

  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: { version: "v2026.2.0", installer: "install_mise" }
packs: {}
EOF

  cat > "${TEST_DIR}/bin/mise" << 'SCRIPT'
#!/usr/bin/env bash
echo "mise v2026.2.10"
SCRIPT
  chmod +x "${TEST_DIR}/bin/mise"

  cat > "${TEST_DIR}/mise_installer.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -e
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/mise" << EOF
#!/usr/bin/env bash
echo "mise ${MISE_VERSION}"
EOF
chmod +x "$HOME/.local/bin/mise"
SCRIPT
  chmod +x "${TEST_DIR}/mise_installer.sh"

  run env \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    DEVBASE_LIBS="${DEVBASE_ROOT}/libs" \
    PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml" \
    SELECTED_PACKS="" \
    _DEVBASE_TEMP="${TEST_DIR}/tmp" \
    PATH="${TEST_DIR}/bin:$PATH" \
    TEST_DIR="${TEST_DIR}" \
    HOME="${HOME}" \
    bash -c '
    cat > "${TEST_DIR}/mock-fns.sh" << "SCRIPT"
retry_command() { "$@"; }
download_file() { cp "${TEST_DIR}/mise_installer.sh" "$2"; }
verify_mise_checksum() { return 0; }
SCRIPT

    source "${DEVBASE_ROOT}/libs/constants.sh"
    source "${DEVBASE_ROOT}/libs/define-colors.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/validation.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/parse-packages.sh"
    source "${DEVBASE_ROOT}/libs/install-mise.sh"
    source "${TEST_DIR}/mock-fns.sh"

    update_mise_if_needed
    if [[ -f "${HOME}/.local/bin/mise" ]]; then
      "${HOME}/.local/bin/mise" --version
    else
      echo "no-install"
    fi
  '

  assert_success
  assert_output --partial "no-install"
}

@test "_run_mise_installer dies if asset checksum is missing from SHASUMS256.txt" {
  mkdir -p "${TEST_DIR}/.config/devbase"
  mkdir -p "${TEST_DIR}/tmp"

  cat > "${TEST_DIR}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    mise: { version: "v2026.2.0", installer: "install_mise" }
packs: {}
EOF

  run env \
    DEVBASE_ROOT="${DEVBASE_ROOT}" \
    DEVBASE_DOT="${TEST_DIR}" \
    DEVBASE_LIBS="${DEVBASE_ROOT}/libs" \
    PACKAGES_YAML="${TEST_DIR}/.config/devbase/packages.yaml" \
    SELECTED_PACKS="" \
    _DEVBASE_TEMP="${TEST_DIR}/tmp" \
    TEST_DIR="${TEST_DIR}" \
    HOME="${HOME}" \
    bash -c '
    cat > "${TEST_DIR}/mock-fns.sh" << "SCRIPT"
# Stub SHASUMS download with a manifest that does not contain our asset
retry_command() {
  local out_file="${@: -1}"
  echo "deadbeef  ./mise-v0.0.0-linux-x64.tar.gz" > "$out_file"
}
download_file() { return 0; }
SCRIPT

    source "${DEVBASE_ROOT}/libs/constants.sh"
    source "${DEVBASE_ROOT}/libs/define-colors.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/validation.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/utils.sh" >/dev/null 2>&1
    source "${DEVBASE_ROOT}/libs/parse-packages.sh"
    source "${DEVBASE_ROOT}/libs/install-mise.sh"
    source "${TEST_DIR}/mock-fns.sh"

    # Run in a nested subshell so die() does not abort the outer bash -c
    ( _run_mise_installer "Test installing mise" ) 2>&1
  '

  assert_failure
  assert_output --partial "No checksum found"
}

# mise installs the rest of the toolchain, so its own binary is the root of
# the supply chain.

_mise_checksum_harness() {
  local served_digest="$1"
  cat <<SCRIPT
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_BIN_HOME='${TEST_DIR}/bin'
    export _DEVBASE_TEMP='${TEST_DIR}/tmp'
    mkdir -p "\$XDG_BIN_HOME" "\$_DEVBASE_TEMP"
    printf 'not-a-real-mise\n' > "\$XDG_BIN_HOME/mise"

    source '${DEVBASE_ROOT}/libs/constants.sh'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1

    retry_command() {
      while [[ "\$1" == --* ]]; do shift 2; done
      [[ "\$1" == "--" ]] && shift
      local out=""; local prev=""
      for a in "\$@"; do [[ "\$prev" == "-o" ]] && out="\$a"; prev="\$a"; done
      printf '%s  mise-v9.9.9-linux-x64.tar.gz\n' '${served_digest}' > "\$out"
      return 0
    }
    _get_mise_arch() { echo x64; }

    verify_mise_checksum '9.9.9'
SCRIPT
}

@test "verify_mise_checksum rejects a binary whose digest does not match" {
  run --separate-stderr bash -c "$(_mise_checksum_harness 0000000000000000000000000000000000000000000000000000000000000000)"

  assert_failure
  [[ "$output$stderr" == *"checksum mismatch"* || "$output$stderr" == *"mismatch"* ]]
}

@test "verify_mise_checksum accepts a binary whose digest matches" {
  mkdir -p "${TEST_DIR}/bin"
  printf 'not-a-real-mise\n' >"${TEST_DIR}/bin/mise"
  local digest
  digest=$(sha256sum "${TEST_DIR}/bin/mise" | cut -d' ' -f1)

  run --separate-stderr bash -c "$(_mise_checksum_harness "$digest")"

  assert_success
}

# Real parser/generator and file operations; external installation is stubbed.
_setup_managed_mise_install() {
  source_core_libs
  source "${DEVBASE_LIBS}/utils.sh"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export _DEVBASE_TEMP="${TEST_DIR}/tmp"
  export DEVBASE_SELECTED_PACKS="node"
  mkdir -p "${DEVBASE_DOT}/.config/devbase" "$_DEVBASE_TEMP" "${XDG_CONFIG_HOME}/mise"
  cat >"${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  mise:
    jq: {version: "1.7"}
packs:
  node:
    mise:
      node: {version: "24.1.0"}
  python:
    mise:
      python: {version: "3.13.0"}
EOF
  cat >"${XDG_CONFIG_HOME}/mise/config.toml" <<'EOF'
# Existing global config must be backed up before regeneration.
[tools]
node = "22.0.0"
[settings]
jobs = 2
[env]
PERSONAL = "keep"
[tasks.mine]
run = "echo personal"
EOF
  cp "${XDG_CONFIG_HOME}/mise/config.toml" "${TEST_DIR}/personal-before"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  source "${DEVBASE_LIBS}/install-mise.sh"
  show_progress() { printf '%s: %s\n' "$1" "$2"; }
  add_install_warning() { printf 'warning: %s\n' "$*"; }
  die() { printf 'error: %s\n' "$*" >&2; exit 1; }
  # Do not depend on (or purge) a host mise package.
  command() {
    [[ "$*" == '-v /usr/bin/mise' ]] && return 1
    builtin command "$@"
  }
  dpkg() { return 1; }
  just() { :; }
  cat >"${XDG_BIN_HOME}/mise" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TEST_DIR}/mise-calls"
case "$*" in
  'env -s bash') printf "export PATH='%s'\n" "$PATH" ;;
  trust\ *) exit 0 ;;
  *) exit 1 ;;
esac
SCRIPT
  chmod +x "${XDG_BIN_HOME}/mise"
}

@test "install_mise regenerates the global config and backs up its previous contents" {
  _setup_managed_mise_install

  run install_mise

  assert_success
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  assert_dir_not_exists "${XDG_CONFIG_HOME}/mise/conf.d"
  run cat "${XDG_CONFIG_HOME}/mise/config.toml"
  assert_output --partial '# Managed by DevBase'
  assert_output --partial 'node = "24.1.0"'
  run cat "${TEST_DIR}/mise-calls"
  assert_line "trust ${XDG_CONFIG_HOME}/mise/config.toml"
  refute_output --partial 'trust --all'
  refute_output --partial 'use -g'
}

@test "install_mise regenerates after pack selection and skips backups for unchanged config" {
  _setup_managed_mise_install
  rm "${XDG_CONFIG_HOME}/mise/config.toml"
  install_mise
  install_mise
  assert_file_not_exists "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  export DEVBASE_SELECTED_PACKS="python"

  install_mise

  run cat "${XDG_CONFIG_HOME}/mise/config.toml"
  assert_output --partial 'python = "3.13.0"'
  refute_output --partial 'node ='
  run cat "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  assert_output --partial 'node = "24.1.0"'
}

@test "install_mise preserves the global config when generation fails" {
  _setup_managed_mise_install
  printf 'core: [broken\n' >"$PACKAGES_YAML"

  run install_mise

  assert_failure
  assert_output --partial 'Failed to generate mise config'
  assert_file_not_exists "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
}

@test "install_mise rejects invalid generated TOML before touching active config" {
  _setup_managed_mise_install
  cat >"$PACKAGES_YAML" <<'EOF'
core:
  mise: {}
packs:
  node:
    mise:
      node: {version: '24.1.0"broken'}
EOF

  run install_mise

  assert_failure
  assert_output --partial 'Generated mise config is not valid TOML'
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
  assert_file_not_exists "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  run find "${XDG_CONFIG_HOME}/mise" -name 'config.toml.*'
  assert_success
  assert_output ''

  rm "${XDG_CONFIG_HOME}/mise/config.toml"
  run install_mise
  assert_failure
  assert_file_not_exists "${XDG_CONFIG_HOME}/mise/config.toml"
}

@test "install_mise refuses a symlink global config without changing its target" {
  _setup_managed_mise_install
  mv "${XDG_CONFIG_HOME}/mise/config.toml" "${TEST_DIR}/linked-config.toml"
  ln -s "${TEST_DIR}/linked-config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"

  run install_mise

  assert_failure
  assert_output --partial 'Refusing to overwrite managed mise config'
  assert_symlink_to "${TEST_DIR}/linked-config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
}

@test "install_mise preserves a dangling global config symlink" {
  _setup_managed_mise_install
  rm "${XDG_CONFIG_HOME}/mise/config.toml"
  ln -s missing.toml "${XDG_CONFIG_HOME}/mise/config.toml"

  run install_mise

  assert_failure
  assert_equal "$(readlink "${XDG_CONFIG_HOME}/mise/config.toml")" missing.toml
  assert_file_not_exists "${XDG_CONFIG_HOME}/mise/missing.toml"
}

@test "install_mise keeps defaults when their backup fails" {
  _setup_managed_mise_install
  cp() { return 1; }

  run install_mise

  assert_failure
  assert_output --partial 'Failed to back up mise config'
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
}

@test "install_mise keeps active defaults and their backup when publication fails" {
  _setup_managed_mise_install
  mv() { return 1; }

  run install_mise

  assert_failure
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
}

@test "install_mise backs up a previous backup symlink without writing through it" {
  _setup_managed_mise_install
  local fragment="${XDG_CONFIG_HOME}/mise/config.toml"
  printf '# old defaults\n' >"$fragment"
  printf 'personal\n' >"${TEST_DIR}/linked-backup"
  ln -s "${TEST_DIR}/linked-backup" "${fragment}-backup"

  run install_mise

  assert_success
  assert_equal "$(cat "${TEST_DIR}/linked-backup")" personal
  assert_equal "$(cat "${fragment}-backup")" '# old defaults'
  assert_symlink_to "${TEST_DIR}/linked-backup" "${fragment}-backup.~1~"
}

@test "install_mise warns about MISE_GLOBAL_CONFIG_FILE without writing it" {
  _setup_managed_mise_install
  export MISE_GLOBAL_CONFIG_FILE="${TEST_DIR}/alternate.toml"
  cp "${TEST_DIR}/personal-before" "$MISE_GLOBAL_CONFIG_FILE"

  run install_mise

  assert_success
  assert_output --partial 'MISE_GLOBAL_CONFIG_FILE is set'
  cmp "${TEST_DIR}/personal-before" "$MISE_GLOBAL_CONFIG_FILE"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
}

_setup_bootstrap_mise_install() {
  _setup_managed_mise_install
  export TEST_YQ_BINARY
  TEST_YQ_BINARY=$(builtin command -v yq)
  unset -f just
  # These directories deliberately differ from any effective personal pin.
  mkdir -p "${TEST_DIR}/bootstrap-yq" "${TEST_DIR}/bootstrap-just"
  cat >"${XDG_BIN_HOME}/mise" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TEST_DIR}/mise-calls"
case "$*" in
  '--no-config install aqua:mikefarah/yq@v4.54.1 --yes')
    ln -sf "$TEST_YQ_BINARY" "${TEST_DIR}/bootstrap-yq/yq" ;;
  '--no-config install aqua:casey/just@1.58.0 --yes')
    printf '#!/bin/sh\nexit 0\n' >"${TEST_DIR}/bootstrap-just/just"
    chmod +x "${TEST_DIR}/bootstrap-just/just" ;;
  '--no-config which yq --tool aqua:mikefarah/yq@v4.54.1')
    printf '%s\n' "${TEST_DIR}/bootstrap-yq/yq" ;;
  '--no-config which just --tool aqua:casey/just@1.58.0')
    printf '%s\n' "${TEST_DIR}/bootstrap-just/just" ;;
  'env -s bash') printf "export PATH='%s:/usr/bin:/bin'\n" "$XDG_BIN_HOME" ;;
  trust\ *) exit 0 ;;
  *) exit 1 ;;
esac
SCRIPT
  # shellcheck disable=SC2329 # Called indirectly by install_mise.
  command() {
    [[ "$*" == '-v /usr/bin/mise' ]] && return 1
    [[ "$*" == '-v yq' && ! -x "${TEST_DIR}/bootstrap-yq/yq" ]] && return 1
    [[ "$*" == '-v just' && ! -x "${TEST_DIR}/bootstrap-just/just" ]] && return 1
    builtin command "$@"
  }
}

@test "install_mise bootstraps yq and just using explicit version specs" {
  _setup_bootstrap_mise_install

  install_mise

  assert_equal "$(command -v yq)" "${TEST_DIR}/bootstrap-yq/yq"
  assert_equal "$(command -v just)" "${TEST_DIR}/bootstrap-just/just"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  run cat "${TEST_DIR}/mise-calls"
  assert_line '--no-config install aqua:mikefarah/yq@v4.54.1 --yes'
  assert_line '--no-config install aqua:casey/just@1.58.0 --yes'
  assert_line '--no-config which yq --tool aqua:mikefarah/yq@v4.54.1'
  assert_line '--no-config which just --tool aqua:casey/just@1.58.0'
  refute_output --partial 'use -g'
}

@test "install_mise bootstraps just even when yq is already available" {
  _setup_bootstrap_mise_install
  ln -s "$TEST_YQ_BINARY" "${TEST_DIR}/bootstrap-yq/yq"
  export PATH="${TEST_DIR}/bootstrap-yq:$PATH"

  install_mise

  assert_equal "$(command -v just)" "${TEST_DIR}/bootstrap-just/just"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  run cat "${TEST_DIR}/mise-calls"
  assert_line '--no-config install aqua:casey/just@1.58.0 --yes'
  refute_line '--no-config install aqua:mikefarah/yq@v4.54.1 --yes'
  refute_output --partial 'use -g'
}

@test "install_mise recovers a broken yq on PATH using the explicit bootstrap version" {
  _setup_bootstrap_mise_install
  printf '#!/bin/sh\nexit 1\n' >"${XDG_BIN_HOME}/yq"
  chmod +x "${XDG_BIN_HOME}/yq"
  # shellcheck disable=SC2329 # Called indirectly by install_mise.
  command() {
    [[ "$*" == '-v /usr/bin/mise' ]] && return 1
    builtin command "$@"
  }

  install_mise

  assert_equal "$(command -v yq)" "${TEST_DIR}/bootstrap-yq/yq"
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml-backup"
  run cat "${TEST_DIR}/mise-calls"
  assert_line '--no-config install aqua:mikefarah/yq@v4.54.1 --yes'
  refute_output --partial 'use -g'
}

@test "install_mise_tools retries effective runtime selections and warns without activating defaults" {
  _setup_managed_mise_install
  get_core_runtimes() { printf 'node\n'; }
  run_mise_from_home_dir() {
    printf '%s\n' "$*" >>"${TEST_DIR}/mise-calls"
    case "$1" in
      which) return 1 ;;
      use) printf 'unexpected write' >"${XDG_CONFIG_HOME}/mise/config.toml"; return 1 ;;
      *) return 0 ;;
    esac
  }

  run install_mise_tools

  assert_success
  assert_output --partial 'Missing critical development tools: node'
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
  run cat "${TEST_DIR}/mise-calls"
  assert_line 'install node --yes'
  assert_line 'install --yes'
  assert_line 'which node'
  assert_line "trust ${XDG_CONFIG_HOME}/mise/config.toml"
  refute_output --partial 'use -g'
  refute_output --partial 'trust --all'
}

_load_mise_verification() {
  source <(sed -n '/^check_mise_tools()/,/^}/p' "${DEVBASE_ROOT}/verify/verify-install-check.sh")
  MISE_CONFIG="${XDG_CONFIG_HOME}/mise/config.toml"
  GREEN='' RED='' NC='' DIM='' CHECK='+' CROSS='-'
  print_subheader() { :; }
  file_exists() { [[ -f "$1" ]]; }
}

@test "mise verification reports the installed effective version separately from the managed default" {
  _setup_managed_mise_install
  install_mise
  _load_mise_verification
  # shellcheck disable=SC2329 # Called by the extracted verifier.
  mise() {
    [[ "$*" == "--cd $HOME list --current --installed --no-header" ]] || return 1
    printf 'node 22.0.0\n'
  }

  run check_mise_tools

  assert_success
  assert_output --partial 'node (effective: 22.0.0; DevBase default: 24.1.0)'
  assert_output --partial 'jq (no installed effective version; DevBase default: 1.7)'
}

@test "mise verification does not count an inactive cached version or an arbitrary PATH command" {
  _setup_managed_mise_install
  install_mise
  _load_mise_verification
  # shellcheck disable=SC2329 # Called by the extracted verifier.
  mise() {
    # A plain list would include the old cached version, which proves nothing
    # about whether the user's effective selection is installed.
    [[ "$*" == "--cd $HOME list --current --installed --no-header" ]] && return 0
    printf 'node 24.1.0\n'
  }
  has_command() { return 0; }

  check_mise_tools

  assert_equal "$MISE_INSTALLED_COUNT" 0
  assert_equal "$MISE_TOTAL_COUNT" 2
}

@test "native mise resolves an explicit bootstrap spec without changing effective personal selection" {
  [[ -x "${DEVBASE_TEST_MISE_BIN:-}" ]] || skip 'Set DEVBASE_TEST_MISE_BIN to the pinned mise binary for native validation'
  _setup_managed_mise_install
  export MISE_OFFLINE=true
  export MISE_YES=1
  # Model two already-installed core runtimes; this test never downloads tools.
  mkdir -p "${MISE_DATA_DIR}/installs/node/22.0.0/bin" "${MISE_DATA_DIR}/installs/node/24.1.0/bin"
  printf '#!/bin/sh\necho v22.0.0\n' >"${MISE_DATA_DIR}/installs/node/22.0.0/bin/node"
  printf '#!/bin/sh\necho v24.1.0\n' >"${MISE_DATA_DIR}/installs/node/24.1.0/bin/node"
  chmod +x "${MISE_DATA_DIR}/installs/node/22.0.0/bin/node" "${MISE_DATA_DIR}/installs/node/24.1.0/bin/node"
  "$DEVBASE_TEST_MISE_BIN" --cd "$HOME" trust "${XDG_CONFIG_HOME}/mise/config.toml"

  _mise_remember_bootstrap_bin node "$DEVBASE_TEST_MISE_BIN" node@24.1.0

  assert_equal "$_DEVBASE_BOOTSTRAP_BINS" "${MISE_DATA_DIR}/installs/node/24.1.0/bin"
  run "$DEVBASE_TEST_MISE_BIN" --cd "$HOME" which node --version
  assert_success
  assert_output '22.0.0'
  cmp "${TEST_DIR}/personal-before" "${XDG_CONFIG_HOME}/mise/config.toml"
  _load_mise_verification
  mise() { "$DEVBASE_TEST_MISE_BIN" "$@"; }
  run check_mise_tools
  assert_success
  assert_output --partial 'node (effective: 22.0.0; DevBase default: 22.0.0)'
  refute_output --partial 'effective: 24.1.0'
}
