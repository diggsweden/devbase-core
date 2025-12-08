#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for setup.sh

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "setup.sh requires bash not sh" {
  run sh "${DEVBASE_ROOT}/setup.sh" --help 2>&1
  
  assert_failure
  assert_output --regexp "(must be run with bash|Illegal option)"
}

@test "setup.sh shows help with --help" {
  run bash "${DEVBASE_ROOT}/setup.sh" --help
  
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--non-interactive"
}

@test "parse_arguments sets NON_INTERACTIVE for --non-interactive" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    NON_INTERACTIVE=false
    parse_arguments --non-interactive
    echo \"\$NON_INTERACTIVE\"
  "
  
  assert_success
  assert_output "true"
}

@test "initialize_devbase_paths sets required paths" {
  run bash -c "
    cd '${DEVBASE_ROOT}'
    eval \"\$(sed -n '/^initialize_devbase_paths()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    initialize_devbase_paths
    echo \"ROOT=\$DEVBASE_ROOT\"
    echo \"LIBS=\$DEVBASE_LIBS\"
    echo \"DOT=\$DEVBASE_DOT\"
  "
  
  assert_success
  assert_output --partial "ROOT="
  assert_output --partial "/libs"
  assert_output --partial "/dot"
}

@test "validate_custom_directory requires config dir" {
  mkdir -p "${TEST_DIR}/custom"
  
  run bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    eval \"\$(sed -n '/^validate_custom_directory()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    validate_custom_directory '${TEST_DIR}/custom'
  "
  
  assert_failure
}

@test "validate_custom_directory requires org.env file" {
  mkdir -p "${TEST_DIR}/custom/config"
  
  run bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    eval \"\$(sed -n '/^validate_custom_directory()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    validate_custom_directory '${TEST_DIR}/custom'
  "
  
  assert_failure
}

@test "validate_custom_directory succeeds with valid structure" {
  mkdir -p "${TEST_DIR}/custom/config"
  touch "${TEST_DIR}/custom/config/org.env"
  
  run bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    eval \"\$(sed -n '/^validate_custom_directory()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    validate_custom_directory '${TEST_DIR}/custom'
  "
  
  assert_success
}

@test "mask_url_credentials masks user:pass in URL" {
  run bash -c "
    eval \"\$(sed -n '/^mask_url_credentials()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    echo 'http://user:secret@proxy.example.com:8080' | mask_url_credentials
  "
  
  assert_success
  assert_output "http://***:***@proxy.example.com:8080"
}

@test "mask_url_credentials preserves URL without credentials" {
  run bash -c "
    eval \"\$(sed -n '/^mask_url_credentials()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    echo 'http://proxy.example.com:8080' | mask_url_credentials
  "
  
  assert_success
  assert_output "http://proxy.example.com:8080"
}

@test "configure_proxy_settings exports proxy variables" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    eval \"\$(sed -n '/^configure_proxy_settings()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    
    DEVBASE_PROXY_HOST='proxy.example.com'
    DEVBASE_PROXY_PORT='8080'
    DEVBASE_NO_PROXY_DOMAINS='localhost,internal.example.com'
    
    configure_proxy_settings
    
    echo \"http_proxy=\$http_proxy\"
    echo \"no_proxy=\$no_proxy\"
  "
  
  assert_success
  assert_output --partial "http_proxy=http://proxy.example.com:8080"
  assert_output --partial "no_proxy=localhost,internal.example.com"
}

@test "configure_proxy_settings sets default no_proxy when not specified" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    eval \"\$(sed -n '/^configure_proxy_settings()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    
    DEVBASE_PROXY_HOST='proxy.example.com'
    DEVBASE_PROXY_PORT='8080'
    DEVBASE_NO_PROXY_DOMAINS=''
    
    configure_proxy_settings
    
    echo \"no_proxy=\$no_proxy\"
  "
  
  assert_success
  assert_output --partial "no_proxy=localhost,127.0.0.1,::1"
}

@test "configure_proxy_settings does nothing without proxy config" {
  run bash -c "
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    eval \"\$(sed -n '/^configure_proxy_settings()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    
    DEVBASE_PROXY_HOST=''
    DEVBASE_PROXY_PORT=''
    
    configure_proxy_settings
    
    echo \"http_proxy=\${http_proxy:-unset}\"
  "
  
  assert_success
  assert_output "http_proxy=unset"
}
