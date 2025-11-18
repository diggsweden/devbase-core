#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Configure curl for proxy environments to avoid connection reuse issues
# Some corporate proxies have problems with persistent connections
configure_proxy_settings() {
  if [[ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]]; then
    # Use curl's environment variables for proxy compatibility
    # These are respected by libcurl and curl command

    # Disable connection reuse - curl checks these env vars
    export CURLOPT_FORBID_REUSE=1
    export CURLOPT_FRESH_CONNECT=1

    # For wget compatibility
    export WGET_OPTIONS="--no-http-keep-alive"

    # Create a custom curl alias with required options
    # This way all curl calls in subshells will use these options
    curl() {
      command curl --no-keepalive --no-sessionid -H "Connection: close" "$@"
    }
    export -f curl

    # Mark as configured
    export DEVBASE_PROXY_CONFIGURED=1
  fi
}

# Call the configuration function
configure_proxy_settings

# Brief: Verify file checksum from URL
# Params: $1-target_file $2-checksum_url $3-timeout
# Returns: 0 if checksum matches, 1 if mismatch
# Side-effects: Downloads checksum file, shows detailed error on mismatch
verify_checksum_from_url() {
  local target="$1"
  local checksum_url="$2"
  local timeout="${3:-30}"
  local checksum_file="${target}.sha256"

  if ! curl -fsSL --connect-timeout "$timeout" "$checksum_url" -o "$checksum_file"; then
    show_progress warning "Could not fetch checksum file from: $checksum_url"
    show_progress info "Continuing without checksum verification (not recommended)"
    return 0 # Don't fail if checksum unavailable
  fi

  # Extract just the checksum (handle various formats: "hash" or "hash *filename" or "hash  filename")
  local expected_sum
  expected_sum=$(head -n1 "$checksum_file" | awk '{print $1}')
  local actual_sum
  actual_sum=$(sha256sum "$target" | awk '{print $1}')

  rm -f "$checksum_file"

  if [[ "$actual_sum" == "$expected_sum" ]]; then
    show_progress success "$(basename "$target") ✓"
    return 0
  else
    show_progress error "Checksum mismatch for $(basename "$target")"
    printf "      Expected: %s\n" "$expected_sum"
    printf "      Got:      %s\n" "$actual_sum"
    show_progress warning "File kept at: $target (verify manually or delete to retry)"
    return 1
  fi
}

# Brief: Verify file checksum from expected value
# Params: $1-target_file $2-expected_checksum
# Returns: 0 if checksum matches, 1 if mismatch
# Side-effects: Shows error and deletes file on mismatch
verify_checksum_value() {
  local target="$1"
  local expected_checksum="$2"
  local actual_checksum

  actual_checksum=$(sha256sum "$target" | cut -d' ' -f1)

  if [[ "$actual_checksum" == "$expected_checksum" ]]; then
    show_progress success "$(basename "$target")"
    return 0
  else
    show_progress error "Checksum mismatch for $(basename "$target")"
    printf "      Expected: %s\n" "$expected_checksum"
    printf "      Got:      %s\n" "$actual_checksum"
    rm -f -- "$target"
    return 1
  fi
}

# Brief: Check if file exists for checksum-only verification
# Params: $1-target $2-has_checksum (0=yes, 1=no)
# Returns: 0 if should skip download, 1 if should download
_download_file_should_skip() {
  local target="$1"
  local has_checksum="$2"

  if [[ -f "$target" ]] && [[ "$has_checksum" -eq 0 ]]; then
    show_progress info "File exists, will verify checksum only (use rm to force re-download)"
    return 0
  fi
  return 1
}

# Brief: Build cache filename from target and version
# Params: $1-target $2-version
# Returns: prints cache filename
_download_file_get_cache_name() {
  local target="$1"
  local version="$2"

  if [[ -n "$version" ]]; then
    local base_name
    base_name=$(basename "$target")
    local extension="${base_name##*.}"
    local name_without_ext="${base_name%.*}"
    echo "${name_without_ext}-v${version}.${extension}"
  else
    basename "$target"
  fi
}

# Brief: Try to use cached file
# Params: $1-cached_file $2-target $3-has_checksum
# Returns: 0 if cache used, 1 if should proceed with download
_download_file_try_cache() {
  local cached_file="$1"
  local target="$2"
  local has_checksum="$3"

  if [[ -f "$cached_file" ]] && [[ "$has_checksum" -eq 1 ]]; then
    show_progress info "Using cached: $(basename "$cached_file")"
    cp "$cached_file" "$target"
    return 0
  fi
  return 1
}

# Brief: Perform single download attempt with curl or wget
# Params: $1-url $2-target $3-timeout $4-skip_download
# Returns: 0 on success, 1 on failure
_download_file_attempt() {
  local url="$1"
  local target="$2"
  local timeout="$3"
  local skip_download="$4"

  [[ "$skip_download" == "true" ]] && return 0

  # Try curl first
  if command_exists curl; then
    curl -#fL --connect-timeout 30 --max-time "$timeout" "$url" -o "$target" 2>&1 && return 0
  fi

  # Fallback to wget
  if command_exists wget; then
    wget --timeout="$timeout" --tries=1 --show-progress -O "$target" "$url" 2>&1 && return 0
  fi

  return 1
}

# Brief: Verify downloaded file checksum
# Params: $1-target $2-checksum_url $3-expected_checksum $4-timeout
# Returns: 0 if verified or no checksum, 1 if verification failed
_download_file_verify() {
  local target="$1"
  local checksum_url="$2"
  local expected_checksum="$3"
  local timeout="$4"

  if [[ -n "$expected_checksum" ]]; then
    verify_checksum_value "$target" "$expected_checksum"
  elif [[ -n "$checksum_url" ]]; then
    verify_checksum_from_url "$target" "$checksum_url" "$timeout"
  else
    show_progress success "$(basename "$target")"
    return 0
  fi
}

# Brief: Cache successfully downloaded file
# Params: $1-target $2-cached_file $3-version
# Returns: always 0
_download_file_cache() {
  local target="$1"
  local cached_file="$2"
  local version="$3"

  [[ -n "$version" ]] && cp "$target" "$cached_file" 2>/dev/null || true
  return 0
}

# Brief: Download file with caching, retry logic, and optional checksum verification
# Params: $1-url $2-target $3-checksum_url(opt) $4-expected_checksum(opt) $5-version(opt) $6-timeout(opt) $7-max_retries(opt) $8-retry_delay(opt)
# Uses: XDG_CACHE_HOME (global)
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads file, creates cache, verifies checksums
# Note: If file exists but checksum fails, keeps file and returns error (avoids re-download)
download_file() {
  local url="$1"
  local target="$2"
  local checksum_url="${3:-}"
  local expected_checksum="${4:-}"
  local version="${5:-}"
  local timeout="${6:-30}"
  local max_retries="${7:-3}"
  local retry_delay="${8:-5}"

  validate_not_empty "$url" "URL" || return 1
  validate_not_empty "$target" "target file" || return 1

  # Check if we can skip download and just verify checksum
  local has_checksum=1
  [[ -n "$checksum_url" || -n "$expected_checksum" ]] && has_checksum=0

  local skip_download=false
  _download_file_should_skip "$target" "$has_checksum" && skip_download=true

  # Setup cache
  local cache_dir="${XDG_CACHE_HOME}/devbase/downloads"
  mkdir -p "$cache_dir"
  local cache_name
  cache_name=$(_download_file_get_cache_name "$target" "$version")
  local cached_file="${cache_dir}/${cache_name}"

  # Try to use cached file
  _download_file_try_cache "$cached_file" "$target" "$has_checksum" && return 0

  # Retry loop
  local attempt=1
  while [[ "$attempt" -le "$max_retries" ]]; do
    if ! _download_file_attempt "$url" "$target" "$timeout" "$skip_download"; then
      show_progress warning "Attempt ${attempt}/${max_retries} failed"
      ((attempt++))
      [[ "$attempt" -le "$max_retries" ]] && sleep "$retry_delay"
      continue
    fi

    # Verify checksum
    _download_file_verify "$target" "$checksum_url" "$expected_checksum" "$timeout" || return 1

    # Cache and return success
    _download_file_cache "$target" "$cached_file" "$version"
    return 0
  done

  show_progress error "Failed to download $(basename "$target") after $max_retries attempts"
  return 1
}

# Brief: Check general internet connectivity by testing common sites
# Params: $1 - connection timeout in seconds (optional, default: 3)
# Uses: show_progress (from ui-helpers)
# Returns: 0 if any site reachable, 1 if no connectivity
# Side-effects: Tests network connectivity to github.com, google.com, cloudflare.com
check_network_connectivity() {
  local timeout="${1:-3}"
  local test_sites=("https://github.com" "https://google.com" "https://cloudflare.com")
  local site_reached=false

  for site in "${test_sites[@]}"; do
    if curl -s --connect-timeout "$timeout" --max-time $((timeout * 2)) "$site" &>/dev/null; then
      site_reached=true
      break
    fi
  done

  if [[ "$site_reached" == true ]]; then
    show_progress success "Network connectivity verified"
    return 0
  else
    show_progress error "No external network access - check connection/proxy"
    return 1
  fi
}

# Brief: Check if configured proxy is working
# Params: $1 - timeout in seconds (default: 5)
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT (global, optional)
# Returns: 0 on success, 1 if proxy not working
# Side-effects: Tests proxy connection
check_proxy_connectivity() {
  local timeout="${1:-5}"
  [[ -z "${DEVBASE_PROXY_HOST}" || -z "${DEVBASE_PROXY_PORT}" ]] && return 0

  # Test with a site that should go through proxy (github.com is not in NO_PROXY)
  if curl -s --connect-timeout "$timeout" --max-time $((timeout * 2)) https://github.com &>/dev/null; then
    show_progress info "Proxy works: ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
  else
    show_progress error "Proxy not working: ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
    return 1
  fi
  return 0
}

# Brief: Check if configured container registry is accessible
# Params: $1 - timeout in seconds (default: 5)
# Uses: DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT (global, optional)
# Returns: 0 always (warnings only, non-fatal)
# Side-effects: Tests registry connection
check_registry_connectivity() {
  local timeout="${1:-5}"
  [[ -z "${DEVBASE_REGISTRY_HOST}" || -z "${DEVBASE_REGISTRY_PORT}" ]] && return 0

  # Build registry URL - try HTTPS first (common for registries)
  local registry_url="https://${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT}"

  # Simple connectivity check with --insecure (ignoring cert issues)
  # curl will automatically use http_proxy/https_proxy/no_proxy env vars
  curl -sk --connect-timeout "$timeout" --max-time $((timeout * 2)) "${registry_url}" -o /dev/null
  local curl_exit=$?

  if [[ $curl_exit -eq 0 ]]; then
    show_progress success "Registry accessible: ${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT}"
  else
    show_progress warning "Registry unreachable: ${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT} (exit code: $curl_exit)"
  fi
  return 0
}
