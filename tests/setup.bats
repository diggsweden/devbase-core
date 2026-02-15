#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for setup.sh

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
}

teardown() {
  common_teardown
}

@test "setup.sh requires bash not sh" {
  # Skip on systems where sh is bash (e.g., Fedora) - BASH_VERSION is set even in POSIX mode
  if sh -c 'test -n "${BASH_VERSION:-}"' 2>/dev/null; then
    skip "sh is bash on this system"
  fi

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

@test "parse_arguments sets DEVBASE_TUI_MODE for --tui=whiptail" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    DEVBASE_TUI_MODE=''
    parse_arguments --tui=whiptail
    echo \"\$DEVBASE_TUI_MODE\"
  "
  
  assert_success
  assert_output "whiptail"
}

@test "parse_arguments sets DEVBASE_TUI_MODE for --tui=gum" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    DEVBASE_TUI_MODE=''
    parse_arguments --tui=gum
    echo \"\$DEVBASE_TUI_MODE\"
  "
  
  assert_success
  assert_output "gum"
}

@test "parse_arguments rejects --tui=none (not a valid user option)" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    DEVBASE_TUI_MODE=''
    parse_arguments --tui=none
    echo \"\$DEVBASE_TUI_MODE\"
  "

  assert_failure
}

@test "parse_arguments rejects --tui=basic (no longer supported)" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    DEVBASE_TUI_MODE=''
    parse_arguments --tui=basic
  "
  
  assert_failure
  assert_output --partial "Invalid TUI mode"
}

@test "parse_arguments rejects invalid --tui value" {
  run bash -c "
    eval \"\$(sed -n '/^parse_arguments()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    DEVBASE_TUI_MODE=''
    parse_arguments --tui=invalid
  "
  
  assert_failure
  assert_output --partial "Invalid TUI mode"
}

@test "setup.sh help shows --tui option" {
  run bash "${DEVBASE_ROOT}/setup.sh" --help
  
  assert_success
  assert_output --partial "--tui=<mode>"
}

@test "bootstrap module exposes run_bootstrap" {
  run bash -c "grep -q '^run_bootstrap()' '${DEVBASE_ROOT}/libs/bootstrap.sh'"

  assert_success
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

    # Stub sudo/snap so tests never touch the host
    sudo() { :; }
    snap() { :; }
    export -f sudo snap

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

    # Stub sudo/snap so tests never touch the host
    sudo() { :; }
    snap() { :; }
    export -f sudo snap

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
  run run_isolated "
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

@test "persist_devbase_repos creates core directory" {
  # Create a mock source repo with file:// URL to avoid network operations
  local source_repo="${TEST_DIR}/source-repo"
  create_mock_git_repo "$source_repo" "v1.0.0" "file://${source_repo}"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_DATA_HOME='${XDG_DATA_HOME}'
    export DEVBASE_ROOT='${source_repo}'
    export _DEVBASE_FROM_GIT='true'
    export DEVBASE_CUSTOM_DIR=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    
    # Extract and run persist_devbase_repos
    eval \"\$(sed -n '/^persist_devbase_repos()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    persist_devbase_repos
    
    # Check if core dir was created
    if [[ -d '${XDG_DATA_HOME}/devbase/core/.git' ]]; then
      echo 'core_created=yes'
    else
      echo 'core_created=no'
    fi
  "
  
  assert_success
  assert_output --partial "core_created=yes"
}

@test "persist_devbase_repos respects DEVBASE_CORE_REF" {
  local source_repo="${TEST_DIR}/source-repo"
  create_mock_git_repo "$source_repo" "v1.0.0" "file://${source_repo}"

  # Create a newer commit and tag it for DEVBASE_CORE_REF
  echo "ref" >> "${source_repo}/README.md"
  git -C "$source_repo" add README.md
  git -C "$source_repo" commit -m "ref commit" --quiet
  git -C "$source_repo" tag -a test-ref -m "Release test-ref"

  run bash -c "
    export HOME='${HOME}'
    export XDG_DATA_HOME='${XDG_DATA_HOME}'
    export DEVBASE_ROOT='${source_repo}'
    export _DEVBASE_FROM_GIT='true'
    export DEVBASE_CUSTOM_DIR=''
    export DEVBASE_CORE_REF='test-ref'

    show_progress() { :; }

    eval \"\$(sed -n '/^persist_devbase_repos()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    persist_devbase_repos

    git -C '${XDG_DATA_HOME}/devbase/core' describe --tags --exact-match
  "

  assert_success
  assert_output "test-ref"
}

@test "persist_devbase_repos skips when not from git" {
  run bash -c "
    export HOME='${HOME}'
    export XDG_DATA_HOME='${XDG_DATA_HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _DEVBASE_FROM_GIT='false'
    export DEVBASE_CUSTOM_DIR=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    
    eval \"\$(sed -n '/^persist_devbase_repos()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    persist_devbase_repos
    
    # Core dir should not be created as a git repo
    if [[ -d '${XDG_DATA_HOME}/devbase/core/.git' ]]; then
      echo 'has_git=yes'
    else
      echo 'has_git=no'
    fi
  "
  
  assert_success
  assert_output --partial "has_git=no"
}

@test "persist_devbase_repos clones custom config when present" {
  # Create mock source repos with file:// URLs to avoid network operations
  local source_repo="${TEST_DIR}/source-repo"
  local custom_repo="${TEST_DIR}/custom-repo"
  create_mock_git_repo "$source_repo" "v1.0.0" "file://${source_repo}"
  create_mock_git_repo "$custom_repo" "v0.1.0" "file://${custom_repo}"
  
  run bash -c "
    export HOME='${HOME}'
    export XDG_DATA_HOME='${XDG_DATA_HOME}'
    export DEVBASE_ROOT='${source_repo}'
    export _DEVBASE_FROM_GIT='true'
    export DEVBASE_CUSTOM_DIR='${custom_repo}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    
    eval \"\$(sed -n '/^persist_devbase_repos()/,/^}/p' '${DEVBASE_ROOT}/setup.sh')\"
    persist_devbase_repos
    
    if [[ -d '${XDG_DATA_HOME}/devbase/custom/.git' ]]; then
      echo 'custom_created=yes'
    else
      echo 'custom_created=no'
    fi
  "
  
  assert_success
  assert_output --partial "custom_created=yes"
}
