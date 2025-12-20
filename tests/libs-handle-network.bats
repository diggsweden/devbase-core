#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  source_core_libs
  source "${DEVBASE_ROOT}/libs/handle-network.sh"
}

teardown() {
  common_teardown
}

@test "verify_checksum_value succeeds with correct checksum" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local expected_checksum=$(sha256sum "$test_file" | cut -d' ' -f1)
  
  run --separate-stderr verify_checksum_value "$test_file" "$expected_checksum"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_file_exists "$test_file"
}

@test "verify_checksum_value fails with incorrect checksum" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local wrong_checksum="0000000000000000000000000000000000000000000000000000000000000000"
  
  run --separate-stderr verify_checksum_value "$test_file" "$wrong_checksum"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$output" == *"Checksum mismatch"* ]] || [[ "$stderr" == *"Checksum mismatch"* ]]
  assert_file_not_exists "$test_file"
}

@test "verify_checksum_value removes file on mismatch" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local wrong_checksum="0000000000000000000000000000000000000000000000000000000000000000"
  
  verify_checksum_value "$test_file" "$wrong_checksum" 2>/dev/null || true
  
  assert_file_not_exists "$test_file"
}

@test "verify_checksum_value shows expected vs actual on mismatch" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local expected_checksum="1234567890abcdef"
  local actual_checksum=$(sha256sum "$test_file" | cut -d' ' -f1)
  
  run --separate-stderr verify_checksum_value "$test_file" "$expected_checksum"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$output" == *"Expected: ${expected_checksum}"* ]] || [[ "$stderr" == *"Expected: ${expected_checksum}"* ]]
  [[ "$output" == *"Got:      ${actual_checksum}"* ]] || [[ "$stderr" == *"Got:      ${actual_checksum}"* ]]
}

@test "configure_curl_for_proxy sets curl options when proxy exists" {
  export http_proxy='http://proxy.example.com:8080'
  
  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    echo \"CURLOPT_FORBID_REUSE=\${CURLOPT_FORBID_REUSE}\"
    echo \"CURLOPT_FRESH_CONNECT=\${CURLOPT_FRESH_CONNECT}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "CURLOPT_FORBID_REUSE=1"
  assert_output --partial "CURLOPT_FRESH_CONNECT=1"
}

@test "configure_curl_for_proxy sets wget options when proxy exists" {
  export https_proxy='http://proxy.example.com:8080'
  
  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    echo \"WGET_OPTIONS=\${WGET_OPTIONS}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "WGET_OPTIONS=--no-http-keep-alive"
}

@test "configure_curl_for_proxy does nothing when no proxy configured" {
  # Use run_isolated helper for clean environment
  run --separate-stderr run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    echo \"CURLOPT_FORBID_REUSE=\${CURLOPT_FORBID_REUSE:-unset}\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "CURLOPT_FORBID_REUSE=unset"
}

@test "_download_file_get_cache_name includes version when provided" {
  run --separate-stderr _download_file_get_cache_name '/tmp/package.tar.gz' '1.2.3'
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "package.tar-v1.2.3.gz"
}

@test "_download_file_get_cache_name uses basename when no version" {
  run --separate-stderr _download_file_get_cache_name '/tmp/package.tar.gz' ''
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "package.tar.gz"
}

@test "_download_file_should_skip returns true when file exists with checksum" {
  local test_file="${TEST_DIR}/existing"
  touch "$test_file"
  
  run --separate-stderr _download_file_should_skip "$test_file" 0
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}

@test "_download_file_should_skip returns false when file missing" {
  run --separate-stderr _download_file_should_skip "${TEST_DIR}/nonexistent" 0
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
}

@test "_download_file_try_cache copies from cache when available" {
  local cached="${TEST_DIR}/cached.tar.gz"
  local target="${TEST_DIR}/target.tar.gz"
  echo "cached content" > "$cached"
  
  run --separate-stderr _download_file_try_cache "$cached" "$target" 1
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_file_exists "$target"
  
  run cat "$target"
  assert_output "cached content"
}

@test "verify_checksum_from_url verifies checksum from remote file" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local checksum=$(sha256sum "$test_file" | cut -d' ' -f1)
  local checksum_url="file://${TEST_DIR}/checksum.txt"
  echo "$checksum" > "${TEST_DIR}/checksum.txt"
  
  stub curl "-fsSL --connect-timeout 30 file://${TEST_DIR}/checksum.txt -o * : cp '${TEST_DIR}/checksum.txt' \"\$6\""
  
  run --separate-stderr verify_checksum_from_url "$test_file" "$checksum_url" 30
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  
  unstub curl
}

@test "verify_checksum_from_url continues without verification when checksum unavailable" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  
  stub curl "-fsSL --connect-timeout 30 http://example.com/checksum -o * : exit 1"
  
  run --separate-stderr verify_checksum_from_url "$test_file" 'http://example.com/checksum' 30
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  [[ "$output" == *"Could not fetch checksum"* ]] || [[ "$stderr" == *"Could not fetch checksum"* ]]
  
  unstub curl
}

@test "check_network_connectivity succeeds when sites are reachable" {
  source "${DEVBASE_ROOT}/libs/utils.sh"
  
  stub curl '-sk --connect-timeout 3 --max-time 6 https://github.com : exit 0'
  
  run --separate-stderr check_network_connectivity 3
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  [[ "$output" == *"Network connectivity verified"* ]] || [[ "$stderr" == *"Network connectivity verified"* ]]
  
  unstub curl
}

@test "check_network_connectivity tries multiple sites" {
  source "${DEVBASE_ROOT}/libs/utils.sh"
  
  stub curl \
    '-sk --connect-timeout 3 --max-time 6 https://github.com : exit 1' \
    '-sk --connect-timeout 3 --max-time 6 https://google.com : exit 0'
  
  run --separate-stderr check_network_connectivity 3
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  
  unstub curl
}

@test "check_proxy_connectivity validates proxy when configured" {
  export DEVBASE_PROXY_HOST='proxy.example.com'
  export DEVBASE_PROXY_PORT='8080'
  
  stub curl '-s --connect-timeout 5 --max-time 10 https://github.com : exit 0'
  
  run --separate-stderr check_proxy_connectivity 5
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  [[ "$output" == *"Proxy works"* ]] || [[ "$stderr" == *"Proxy works"* ]]
  
  unstub curl
}

@test "check_proxy_connectivity skips when no proxy configured" {
  run --separate-stderr run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    check_proxy_connectivity
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}
