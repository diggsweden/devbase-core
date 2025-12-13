#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  export DEVBASE_DEBUG="${DEVBASE_DEBUG:-false}"
  export _DEVBASE_CUSTOM_CERTS=""
  # Alias for backward compatibility with tests using TEMP_DIR
  TEMP_DIR="$TEST_DIR"
  export TEMP_DIR
  
  mkdir -p "${TEST_DIR}/bin"
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
}

teardown() {
  common_teardown
}

@test "configure_git_certificate sets Git config for domain" {
  cat > "${TEMP_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    configure_git_certificate 'sub.example.com'
  "
  
  assert_success
}

@test "configure_git_certificate handles base domain wildcards" {
  cat > "${TEMP_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    configure_git_certificate 'git.internal.corp'
  "
  
  assert_success
}

@test "configure_git_certificate rejects invalid domains" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    configure_git_certificate ''
  "
  assert_failure
}

@test "configure_git_certificate rejects domains without dots" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    configure_git_certificate 'localhost'
  "
  assert_failure
}

@test "install_certificates returns early when no custom cert dir" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS=''
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
}

@test "install_certificates returns early when no .crt files found" {
  mkdir -p "${TEMP_DIR}/certs"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS='${TEMP_DIR}/certs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
}

@test "install_certificates validates certificate format with openssl" {
  mkdir -p "${TEMP_DIR}/certs"
  echo "INVALID CERT" > "${TEMP_DIR}/certs/test.crt"
  
  cat > "${TEMP_DIR}/bin/openssl" << 'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "${TEMP_DIR}/bin/openssl"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS='${TEMP_DIR}/certs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
  assert_output --partial "No valid certificates"
}

@test "install_certificates extracts domain from certificate CN" {
  mkdir -p "${TEMP_DIR}/certs"
  touch "${TEMP_DIR}/certs/example.crt"
  
  cat > "${TEMP_DIR}/bin/openssl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$3" == "-subject" ]]; then
  echo "subject=CN = example.com, O = Test"
else
  exit 0
fi
SCRIPT
  chmod +x "${TEMP_DIR}/bin/openssl"
  
  cat > "${TEMP_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/sudo"
  
  cat > "${TEMP_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS='${TEMP_DIR}/certs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
}

@test "install_certificates falls back to filename when no CN" {
  mkdir -p "${TEMP_DIR}/certs"
  touch "${TEMP_DIR}/certs/example.com.crt"
  
  cat > "${TEMP_DIR}/bin/openssl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$3" == "-subject" ]]; then
  echo ""
else
  exit 0
fi
SCRIPT
  chmod +x "${TEMP_DIR}/bin/openssl"
  
  cat > "${TEMP_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/sudo"
  
  cat > "${TEMP_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS='${TEMP_DIR}/certs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
}

@test "install_certificates reports statistics correctly" {
  mkdir -p "${TEMP_DIR}/certs"
  touch "${TEMP_DIR}/certs/test.crt"
  
  cat > "${TEMP_DIR}/bin/openssl" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$3" == "-subject" ]]; then
  echo "CN=test.com"
else
  exit 0
fi
SCRIPT
  chmod +x "${TEMP_DIR}/bin/openssl"
  
  cat > "${TEMP_DIR}/bin/sudo" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "update-ca-certificates" ]]; then
  echo "1 added, 0 removed"
fi
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/sudo"
  
  cat > "${TEMP_DIR}/bin/git" << 'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEMP_DIR}/bin/git"
  
  run bash -c "
    export PATH='${TEMP_DIR}/bin:/usr/bin:/bin'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DEBUG='false'
    export _DEVBASE_CUSTOM_CERTS='${TEMP_DIR}/certs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/install-certificates.sh'
    
    install_certificates
  "
  assert_success
  assert_output --partial "certificate"
}
