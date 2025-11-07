#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

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

  # Check if file already exists (e.g., from previous failed checksum)
  local skip_download=false
  if [[ -f "$target" ]] && [[ -n "$checksum_url" || -n "$expected_checksum" ]]; then
    show_progress info "File exists, will verify checksum only (use rm to force re-download)"
    skip_download=true
  fi

  # Setup cache directory and naming
  local cache_dir="${XDG_CACHE_HOME}/devbase/downloads"
  mkdir -p "$cache_dir"

  local cache_name
  if [[ -n "$version" ]]; then
    local base_name
    base_name=$(basename "$target")
    local extension="${base_name##*.}"
    local name_without_ext="${base_name%.*}"
    cache_name="${name_without_ext}-v${version}.${extension}"
  else
    cache_name="$(basename "$target")"
  fi

  local cached_file="${cache_dir}/${cache_name}"

  # Use cache if available and no checksum verification needed
  if [[ -f "$cached_file" ]] && [[ -z "$checksum_url" ]] && [[ -z "$expected_checksum" ]]; then
    show_progress info "Using cached: ${cache_name}"
    cp "$cached_file" "$target"
    return 0
  fi

  # Retry loop for download
  local attempt=1
  while [[ "$attempt" -le "$max_retries" ]]; do
    local download_success=false
    local curl_exit=0
    local wget_exit=0

    # Skip download if file exists and we're just verifying checksum
    if [[ "$skip_download" == "true" ]]; then
      download_success=true
    else
      # Try curl first (better error handling and progress display)
      if command_exists curl; then
        if curl -#fL --connect-timeout 30 --max-time "$timeout" "$url" -o "$target" 2>&1; then
          download_success=true
        else
          curl_exit=$?
        fi
      fi

      # Fallback to wget if curl failed or not available
      if [[ "$download_success" == "false" ]] && command_exists wget; then
        if wget --timeout="$timeout" --tries=1 --show-progress -O "$target" "$url" 2>&1; then
          download_success=true
        else
          wget_exit=$?
        fi
      fi
    fi

    # Download failed - retry
    if [[ "$download_success" == "false" ]]; then
      show_progress warning "Attempt ${attempt}/${max_retries} failed (curl=$curl_exit, wget=$wget_exit)"
      ((attempt++))
      [[ "$attempt" -le "$max_retries" ]] && sleep "$retry_delay"
      continue
    fi

    # Download succeeded - verify checksum if requested
    local verification_passed=true

    if [[ -n "$expected_checksum" ]]; then
      # Verify with provided checksum value
      verify_checksum_value "$target" "$expected_checksum" || verification_passed=false

    elif [[ -n "$checksum_url" ]]; then
      # Verify with checksum from URL
      verify_checksum_from_url "$target" "$checksum_url" "$timeout" || verification_passed=false

    else
      # No checksum verification
      show_progress success "$(basename "$target")"
    fi

    # Verification failed - return error
    if [[ "$verification_passed" == "false" ]]; then
      return 1
    fi

    # Success! Cache the file if versioned
    if [[ -n "$version" ]]; then
      cp "$target" "$cached_file" 2>/dev/null || true
    fi

    return 0
  done

  # All retries exhausted
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
# Uses: DEVBASE_PROXY_URL (global, optional)
# Returns: 0 on success, 1 if proxy not working
# Side-effects: Tests proxy connection
check_proxy_connectivity() {
  local timeout="${1:-5}"
  [[ -z "${DEVBASE_PROXY_URL:-}" ]] && return 0

  # Test with a site that should go through proxy (github.com is not in NO_PROXY)
  if curl -s --connect-timeout "$timeout" --max-time $((timeout * 2)) https://github.com &>/dev/null; then
    show_progress info "Proxy works: ${DEVBASE_PROXY_URL}"
  else
    show_progress error "Proxy not working: ${DEVBASE_PROXY_URL}"
    return 1
  fi
  return 0
}

# Brief: Check if configured container registry is accessible
# Params: $1 - timeout in seconds (default: 5)
# Uses: DEVBASE_REGISTRY_URL (global, optional)
# Returns: 0 always (warnings only, non-fatal)
# Side-effects: Tests registry connection
check_registry_connectivity() {
  local timeout="${1:-5}"
  [[ -z "${DEVBASE_REGISTRY_URL:-}" ]] && return 0

  # Simple connectivity check with --insecure (ignoring cert issues)
  # curl will automatically use http_proxy/https_proxy/no_proxy env vars
  curl -sk --connect-timeout "$timeout" --max-time $((timeout * 2)) "${DEVBASE_REGISTRY_URL}" -o /dev/null
  local curl_exit=$?

  if [[ $curl_exit -eq 0 ]]; then
    show_progress success "Registry accessible: ${DEVBASE_REGISTRY_URL}"
  else
    show_progress warning "Registry unreachable: ${DEVBASE_REGISTRY_URL} (exit code: $curl_exit)"
  fi
  return 0
}
