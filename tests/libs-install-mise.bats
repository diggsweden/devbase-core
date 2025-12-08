#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export XDG_BIN_HOME="${TEST_DIR}/.local/bin"
  mkdir -p "${XDG_BIN_HOME}"
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "load_all_versions parses YAML version file" {
  local versions_file="${TEST_DIR}/versions.yaml"
  
  cat > "$versions_file" << 'EOF'
# Test versions file
node: "20.10.0"
python: "3.11.5"
go: 1.21.0
# comment line
ruby: '3.2.0'
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _VERSIONS_FILE='${versions_file}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    load_all_versions
    
    echo \"node=\${TOOL_VERSIONS[node]}\"
    echo \"python=\${TOOL_VERSIONS[python]}\"
    echo \"go=\${TOOL_VERSIONS[go]}\"
    echo \"ruby=\${TOOL_VERSIONS[ruby]}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output --partial "node=20.10.0"
  assert_output --partial "python=3.11.5"
  assert_output --partial "go=1.21.0"
  assert_output --partial "ruby=3.2.0"
}

@test "load_all_versions strips quotes from versions" {
  local versions_file="${TEST_DIR}/versions.yaml"
  
  cat > "$versions_file" << 'EOF'
tool1: "1.0.0"
tool2: '2.0.0'
tool3: 3.0.0
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _VERSIONS_FILE='${versions_file}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    load_all_versions >/dev/null 2>&1
    
    # All should be without quotes
    echo \"\${TOOL_VERSIONS[tool1]}\" | grep -q '\"' && echo 'HAS_QUOTES' || echo 'NO_QUOTES'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "NO_QUOTES"
}

@test "load_all_versions skips comment lines" {
  local versions_file="${TEST_DIR}/versions.yaml"
  
  cat > "$versions_file" << 'EOF'
# This is a comment
node: "20.0.0"
# Another comment
python: "3.11.0"
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _VERSIONS_FILE='${versions_file}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    load_all_versions >/dev/null 2>&1
    
    # Should only load 2 tools
    echo \"count=\${#TOOL_VERSIONS[@]}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "count=2"
}

@test "load_all_versions skips empty lines" {
  local versions_file="${TEST_DIR}/versions.yaml"
  
  cat > "$versions_file" << 'EOF'
node: "20.0.0"

python: "3.11.0"

EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _VERSIONS_FILE='${versions_file}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    load_all_versions >/dev/null 2>&1
    
    echo \"count=\${#TOOL_VERSIONS[@]}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "count=2"
}

@test "verify_mise_checksum returns 1 if mise binary doesn't exist" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export XDG_BIN_HOME='${XDG_BIN_HOME}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    verify_mise_checksum && echo 'EXISTS' || echo 'NOT_EXISTS'
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "NOT_EXISTS"
}

@test "load_all_versions fails if versions file doesn't exist" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _VERSIONS_FILE='${TEST_DIR}/nonexistent.yaml'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-mise.sh' >/dev/null 2>&1
    
    load_all_versions 2>&1
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_failure
  assert_output --partial "Versions file not found"
}
