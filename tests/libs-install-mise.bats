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

setup() {
  common_setup_isolated
  export XDG_BIN_HOME="${HOME}/.local/bin"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "node"
  assert_output --partial "java"
  refute_output --partial "python"
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
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "NOT_EXISTS"
}

@test "update_mise_if_needed reinstalls when version mismatches" {
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
echo "mise v2026.1.0"
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
    "${HOME}/.local/bin/mise" --version
  '

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
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

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "no-install"
}
