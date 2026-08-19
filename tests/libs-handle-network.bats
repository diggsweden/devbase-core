#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2027,SC2030,SC2031,SC2086,SC2123,SC2155,SC2218,SC2329
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
  source "${DEVBASE_ROOT}/libs/utils.sh"
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
  
  assert_success
  assert_file_exists "$test_file"
}

@test "verify_checksum_value fails with incorrect checksum" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local wrong_checksum="0000000000000000000000000000000000000000000000000000000000000000"
  
  run --separate-stderr verify_checksum_value "$test_file" "$wrong_checksum"
  
  assert_failure
  [[ "$output" == *"Checksum mismatch"* ]] || [[ "$stderr" == *"Checksum mismatch"* ]]
  assert_file_not_exists "$test_file"
}

@test "verify_checksum_value removes file on mismatch" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local wrong_checksum="0000000000000000000000000000000000000000000000000000000000000000"

  run --separate-stderr verify_checksum_value "$test_file" "$wrong_checksum"

  assert_failure
  assert_file_not_exists "$test_file"
}

@test "verify_checksum_value shows expected vs actual on mismatch" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"
  local expected_checksum="1234567890abcdef"
  local actual_checksum=$(sha256sum "$test_file" | cut -d' ' -f1)
  
  run --separate-stderr verify_checksum_value "$test_file" "$expected_checksum"
  
  assert_failure
  [[ "$output" == *"Expected: ${expected_checksum}"* ]] || [[ "$stderr" == *"Expected: ${expected_checksum}"* ]]
  [[ "$output" == *"Got:      ${actual_checksum}"* ]] || [[ "$stderr" == *"Got:      ${actual_checksum}"* ]]
}

@test "configure_curl_for_proxy sets curl options when proxy exists" {
  export http_proxy='http://proxy.example.com:8080'
  
  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    printf 'CURL_ARGS=%s\n' \"\${DEVBASE_CURL_PROXY_ARGS[*]}\"
  "

  assert_success
  assert_output --partial "CURL_ARGS=--no-keepalive --no-sessionid -H Connection: close"
}

@test "configure_curl_for_proxy sets wget options when proxy exists" {
  export https_proxy='http://proxy.example.com:8080'
  
  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    printf 'WGET_ARGS=%s\n' \"\${DEVBASE_WGET_PROXY_ARGS[*]}\"
  "
  
  assert_success
  assert_output --partial "WGET_ARGS=--no-http-keep-alive"
}

@test "download_file fails without checksum in strict mode" {
  local target="${TEST_DIR}/file"

  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    export XDG_CACHE_HOME='${TEST_DIR}'
    export DEVBASE_STRICT_CHECKSUMS=fail
    download_file 'https://example.com/file' '${target}'
  "

  assert_failure
  [[ "$stderr" == *"Checksum required"* ]]
}

@test "_normalize_download_timeout keeps valid timeout" {
  run --separate-stderr _normalize_download_timeout "45"

  assert_success
  assert_output "45"
}

@test "_normalize_download_timeout falls back for non-numeric timeout" {
  run --separate-stderr _normalize_download_timeout "MonaspiceNe"

  assert_success
  [[ "$output" == *"Invalid download timeout"* ]]
  [[ "$output" == *$'\n30' ]]
}

@test "_normalize_download_timeout falls back for out-of-range timeout" {
  run --separate-stderr _normalize_download_timeout "601"

  assert_success
  [[ "$output" == *"Invalid download timeout"* ]]
  [[ "$output" == *$'\n30' ]]
}

@test "download_file normalizes timeout before download attempt" {
  local target="${TEST_DIR}/timeout-normalized.bin"

  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    export XDG_CACHE_HOME='${TEST_DIR}'
    export DEVBASE_STRICT_CHECKSUMS='off'

    _download_file_attempt() {
      local _url=\"\$1\"
      local _target=\"\$2\"
      local _timeout=\"\$3\"
      local _skip=\"\$4\"
      printf '%s' \"\$_timeout\" > '${TEST_DIR}/timeout-captured.txt'
      [[ \"\$_skip\" == \"true\" ]] && return 0
      printf 'ok' > \"\$_target\"
      return 0
    }

    download_file 'https://example.com/file.bin' '${target}' '' '' '' 'MonaspiceNe'
  "

  assert_success
  assert_file_exists "$target"
  assert_file_exists "${TEST_DIR}/timeout-captured.txt"

  run cat "${TEST_DIR}/timeout-captured.txt"
  assert_success
  assert_output "30"
}


@test "configure_curl_for_proxy does nothing when no proxy configured" {
  # Use run_isolated helper for clean environment
  run --separate-stderr run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    configure_curl_for_proxy
    printf 'CURL_ARGS=%s\n' "${DEVBASE_CURL_PROXY_ARGS[*]}"
  "
  
  assert_success
  assert_output --partial "CURL_ARGS="
}

@test "_download_file_get_cache_name includes version when provided" {
  run --separate-stderr _download_file_get_cache_name '/tmp/package.tar.gz' '1.2.3'
  
  assert_success
  assert_output "package.tar-v1.2.3.gz"
}

@test "_download_file_get_cache_name uses basename when no version" {
  run --separate-stderr _download_file_get_cache_name '/tmp/package.tar.gz' ''

  assert_success
  assert_output "package.tar.gz"
}

@test "_download_file_get_cache_name handles extension-less filename" {
  run --separate-stderr _download_file_get_cache_name '/tmp/mise_installer' '2.1.0'

  assert_success
  assert_output "mise_installer-v2.1.0"
}

@test "_download_file_should_skip returns true when file exists with checksum" {
  local test_file="${TEST_DIR}/existing"
  touch "$test_file"
  
  run --separate-stderr _download_file_should_skip "$test_file" true
  
  assert_success
}

@test "_download_file_should_skip returns false when file missing" {
  run --separate-stderr _download_file_should_skip "${TEST_DIR}/nonexistent" 0
  
  assert_failure
}

@test "_download_file_try_cache copies from cache when available" {
  local cached="${TEST_DIR}/cached.tar.gz"
  local target="${TEST_DIR}/target.tar.gz"
  echo "cached content" > "$cached"
  
  run --separate-stderr _download_file_try_cache "$cached" "$target" false
  
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
  
  assert_success
  
  unstub curl
}

@test "get_checksum_from_manifest returns checksum for filename" {
  local manifest="${TEST_DIR}/checksums.txt"
  local manifest_url="file://${manifest}"
  echo "abcdef1234567890  gum_0.17.0_linux_amd64.deb" > "$manifest"

  stub curl "-fsSL --connect-timeout 30 --max-time 30 ${manifest_url} -o * : cp '${manifest}' \"\$8\""

  run --separate-stderr get_checksum_from_manifest "$manifest_url" "gum_0.17.0_linux_amd64.deb" 30

  assert_success
  assert_output "abcdef1234567890"

  unstub curl
}

@test "get_checksum_from_manifest matches exact filename, not substring" {
  local manifest="${TEST_DIR}/checksums.txt"
  local manifest_url="file://${manifest}"
  cat > "$manifest" << 'EOF'
1111111111111111111111111111111111111111111111111111111111111111  other-gum_0.17.0_linux_amd64.deb
abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890  gum_0.17.0_linux_amd64.deb
EOF

  stub curl "-fsSL --connect-timeout 30 --max-time 30 ${manifest_url} -o * : cp '${manifest}' \"\$8\""

  run --separate-stderr get_checksum_from_manifest "$manifest_url" "gum_0.17.0_linux_amd64.deb" 30

  assert_success
  assert_output "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"

  unstub curl
}

@test "get_checksum_from_manifest fails when filename missing" {
  local manifest="${TEST_DIR}/checksums.txt"
  local manifest_url="file://${manifest}"
  echo "abcdef1234567890  other-file.deb" > "$manifest"

  stub curl "-fsSL --connect-timeout 30 --max-time 30 ${manifest_url} -o * : cp '${manifest}' \"\$8\""

  run --separate-stderr get_checksum_from_manifest "$manifest_url" "gum_0.17.0_linux_amd64.deb" 30

  assert_failure

  unstub curl
}

@test "_checksum_allowlisted matches url against glob patterns" {
  export DEVBASE_STRICT_CHECKSUMS_ALLOWLIST="https://example.com/*, https://mirror.example.org/releases/*"

  run --separate-stderr _checksum_allowlisted "https://mirror.example.org/releases/tool.tar.gz"

  assert_success
}

@test "download_file allows checksumless URL when allowlisted in fail mode" {
  local target="${TEST_DIR}/allowlisted-download.bin"

  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    export XDG_CACHE_HOME='${TEST_DIR}'
    export DEVBASE_STRICT_CHECKSUMS='fail'
    export DEVBASE_STRICT_CHECKSUMS_ALLOWLIST='https://example.com/*'

    _download_file_attempt() {
      local _url=\"\$1\"
      local _target=\"\$2\"
      local _timeout=\"\$3\"
      local _skip=\"\$4\"
      [[ \"\$_skip\" == \"true\" ]] && return 0
      printf 'ok' > \"\$_target\"
      return 0
    }

    download_file 'https://example.com/file.bin' '${target}'
  "

  assert_success
  assert_file_exists "$target"
}

@test "verify_checksum_from_url returns 2 when checksum unavailable" {
  local test_file="${TEST_DIR}/testfile"
  echo "test content" > "$test_file"

  stub curl "-fsSL --connect-timeout 30 http://example.com/checksum -o * : exit 1"

  run --separate-stderr verify_checksum_from_url "$test_file" 'http://example.com/checksum' 30

  assert_failure 2
  [[ "$output" == *"Could not fetch checksum"* ]] || [[ "$stderr" == *"Could not fetch checksum"* ]]

  unstub curl
}

@test "check_network_connectivity succeeds when sites are reachable" {
  source "${DEVBASE_ROOT}/libs/utils.sh"
  
  stub curl '-s --connect-timeout 3 --max-time 6 https://github.com : exit 0'
  
  run --separate-stderr check_network_connectivity 3
  
  assert_success
  [[ "$output" == *"Network connectivity verified"* ]] || [[ "$stderr" == *"Network connectivity verified"* ]]
  
  unstub curl
}

@test "check_network_connectivity tries multiple sites" {
  source "${DEVBASE_ROOT}/libs/utils.sh"
  
  stub curl \
    '-s --connect-timeout 3 --max-time 6 https://github.com : exit 1' \
    '-s --connect-timeout 3 --max-time 6 https://google.com : exit 0'
  
  run --separate-stderr check_network_connectivity 3
  
  assert_success
  
  unstub curl
}

@test "check_proxy_connectivity validates proxy when configured" {
  export DEVBASE_PROXY_HOST='proxy.example.com'
  export DEVBASE_PROXY_PORT='8080'
  
  stub curl '-s --connect-timeout 5 --max-time 10 https://github.com : exit 0'
  
  run --separate-stderr check_proxy_connectivity 5
  
  assert_success
  [[ "$output" == *"Proxy works"* ]] || [[ "$stderr" == *"Proxy works"* ]]
  
  unstub curl
}

@test "check_proxy_connectivity skips when no proxy configured" {
  run --separate-stderr run_isolated "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    check_proxy_connectivity
  "
  
  assert_success
}

@test "download_file fails when the remote checksum does not match the payload" {
  # download_file honouring a mismatch reported via a remote checksum file is
  # the point at which a tampered payload is accepted or rejected.
  local target="${TEST_DIR}/payload.bin"

  run --separate-stderr bash -c "
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/utils.sh'
    source '${DEVBASE_ROOT}/libs/handle-network.sh'
    export XDG_CACHE_HOME='${TEST_DIR}/cache'

    # Serve a payload for the artefact URL and a deliberately wrong digest for
    # the checksum URL.
    devbase_curl() {
      local out='' url='' prev=''
      for a in \"\$@\"; do
        [[ \"\$prev\" == '-o' ]] && out=\"\$a\"
        [[ \"\$a\" == http* ]] && url=\"\$a\"
        prev=\"\$a\"
      done
      if [[ \"\$url\" == *checksums* ]]; then
        printf '%s\n' '0000000000000000000000000000000000000000000000000000000000000000' > \"\$out\"
      else
        printf 'payload\n' > \"\$out\"
      fi
      return 0
    }

    download_file 'https://example.com/payload.bin' '${target}' 'https://example.com/checksums.txt'
  "

  assert_failure
  [[ "$stderr" == *"Checksum mismatch"* ]]
}

# =============================================================================
# _normalize_strict_mode tests
# =============================================================================

@test "_normalize_strict_mode maps legacy boolean values onto modes" {
  run --separate-stderr _normalize_strict_mode "true"
  assert_success
  assert_output "warn"

  run --separate-stderr _normalize_strict_mode "false"
  assert_success
  assert_output "off"
}

@test "_normalize_strict_mode passes warn and fail through unchanged" {
  run --separate-stderr _normalize_strict_mode "warn"
  assert_output "warn"

  run --separate-stderr _normalize_strict_mode "fail"
  assert_output "fail"

  run --separate-stderr _normalize_strict_mode "off"
  assert_output "off"
}

# A blank or missing setting must fail closed. If this ever returns "off" the
# checksum verification in verify_checksum_value is silently disabled.
@test "_normalize_strict_mode falls back to fail when unset or empty" {
  run --separate-stderr _normalize_strict_mode ""
  assert_output "fail"

  run --separate-stderr _normalize_strict_mode
  assert_output "fail"
}

@test "_normalize_strict_mode warns and degrades to warn on an unknown value" {
  run --separate-stderr _normalize_strict_mode "bogus"
  assert_success
  assert_output "warn"
  # The warning must reach stderr, not stdout: stdout is the return value.
  assert_regex "$stderr" "Unknown DEVBASE_STRICT_CHECKSUMS=bogus"
}

# =============================================================================
# require_remote_script_checksum tests
# =============================================================================

@test "require_remote_script_checksum refuses a remote script with no checksum" {
  run --separate-stderr require_remote_script_checksum "https://example.test/i.sh" "" "installer"
  assert_failure
  assert_regex "$stderr$output" "checksum required for remote script"
}

@test "require_remote_script_checksum accepts a remote script with a checksum" {
  run --separate-stderr require_remote_script_checksum "https://example.test/i.sh" "abc123" "installer"
  assert_success
}

# =============================================================================
# _download_file_verify tests
#
# The two verify_* helpers are replaced per test to reach the branch under
# test. What matters is which return code maps to which outcome: rc=1 is a
# real mismatch and must always fail, rc=2 is an unavailable checksum and
# depends on strict_mode.
# =============================================================================

@test "_download_file_verify fails when an explicit checksum does not match" {
  verify_checksum_value() { return 1; }
  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "" "deadbeef" 30 "warn"
  assert_failure
}

@test "_download_file_verify succeeds when an explicit checksum matches" {
  verify_checksum_value() { return 0; }
  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "" "cafebabe" 30 "warn"
  assert_success
}

@test "_download_file_verify fails on a mismatch from a checksum URL even when lenient" {
  verify_checksum_from_url() { return 1; }
  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "https://example.test/sums" "" 30 "warn"
  assert_failure
}

@test "_download_file_verify fails on an unavailable checksum only in fail mode" {
  verify_checksum_from_url() { return 2; }

  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "https://example.test/sums" "" 30 "fail"
  assert_failure
  assert_regex "$stderr$output" "Checksum required but unavailable"

  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "https://example.test/sums" "" 30 "warn"
  assert_success
}

@test "_download_file_verify succeeds when no checksum was requested at all" {
  run --separate-stderr _download_file_verify "${TEST_DIR}/f" "" "" 30 "warn"
  assert_success
}

# =============================================================================
# devbase_wget tests
# =============================================================================

@test "devbase_wget passes the configured proxy arguments through to wget" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/wget" << 'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*"
SCRIPT
  chmod +x "${TEST_DIR}/bin/wget"
  export PATH="${TEST_DIR}/bin:${PATH}"
  DEVBASE_WGET_PROXY_ARGS=(--no-http-keep-alive)

  run --separate-stderr devbase_wget "https://example.test/f"

  assert_success
  assert_output "--no-http-keep-alive https://example.test/f"
}

# =============================================================================
# _download_file_cache tests
# =============================================================================

@test "_download_file_cache stores the file when a version is known" {
  echo "payload" > "${TEST_DIR}/downloaded"

  run --separate-stderr _download_file_cache "${TEST_DIR}/downloaded" "${TEST_DIR}/cached" "1.2.3"

  assert_success
  assert_equal "$(cat "${TEST_DIR}/cached")" "payload"
}

# Without a version the cache key would be ambiguous, so nothing is stored.
@test "_download_file_cache stores nothing when the version is unknown" {
  echo "payload" > "${TEST_DIR}/downloaded"

  run --separate-stderr _download_file_cache "${TEST_DIR}/downloaded" "${TEST_DIR}/cached" ""

  assert_success
  assert_file_not_exists "${TEST_DIR}/cached"
}

@test "_download_file_cache succeeds even when the cache is not writable" {
  echo "payload" > "${TEST_DIR}/downloaded"

  # Caching is best-effort; a failure here must never fail the download.
  run --separate-stderr _download_file_cache "${TEST_DIR}/downloaded" "${TEST_DIR}/absent/cached" "1.2.3"

  assert_success
}

# =============================================================================
# check_registry_connectivity tests
# =============================================================================

@test "check_registry_connectivity does nothing when no registry is configured" {
  unset DEVBASE_REGISTRY_HOST DEVBASE_REGISTRY_PORT
  devbase_curl() { touch "${TEST_DIR}/curl-was-called"; return 0; }

  run --separate-stderr check_registry_connectivity 1

  assert_success
  # An unconfigured registry must not probe the network or warn about it.
  assert_file_not_exists "${TEST_DIR}/curl-was-called"
  refute_output --partial "Registry"
}

@test "check_registry_connectivity reports a reachable registry" {
  export DEVBASE_REGISTRY_HOST="registry.test" DEVBASE_REGISTRY_PORT="5000"
  devbase_curl() { return 0; }

  run --separate-stderr check_registry_connectivity 1

  assert_success
  assert_regex "$stderr$output" "Registry accessible: registry.test:5000"
}

@test "check_registry_connectivity warns but does not fail on an unreachable registry" {
  export DEVBASE_REGISTRY_HOST="registry.test" DEVBASE_REGISTRY_PORT="5000"
  devbase_curl() { return 7; }

  run --separate-stderr check_registry_connectivity 1

  # Returning non-zero here would abort setup over an optional registry.
  assert_success
  assert_regex "$stderr$output" "Registry unreachable: registry.test:5000"
}

# =============================================================================
# _ensure_progress_logger tests
# =============================================================================

@test "_ensure_progress_logger provides show_progress when none is loaded" {
  unset -f show_progress

  _ensure_progress_logger

  assert [ -n "$(declare -f show_progress)" ]
  run --separate-stderr show_progress info "hello"
  assert_success
  assert_regex "$stderr$output" "hello"
}
