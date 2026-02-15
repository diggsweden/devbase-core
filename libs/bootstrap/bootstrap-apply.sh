#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

apply_environment_settings() {
  # Export registry settings immediately after loading environment
  # This ensures they're available for connectivity checks and installations
  if [[ -n "${DEVBASE_REGISTRY_HOST}" ]]; then
    export DEVBASE_REGISTRY_HOST
    export DEVBASE_REGISTRY_PORT
  fi

  if [[ -n "${DEVBASE_PYPI_REGISTRY}" ]]; then
    export PIP_INDEX_URL="${DEVBASE_PYPI_REGISTRY}"
  fi

  # Export proxy settings immediately after loading environment
  # This ensures they're available for configure_proxy_settings() and network operations
  if [[ -n "${DEVBASE_PROXY_HOST}" ]]; then
    export DEVBASE_PROXY_HOST
    export DEVBASE_PROXY_PORT
    export DEVBASE_NO_PROXY_DOMAINS
  fi

  return 0
}

# Brief: Configure proxy environment variables for network operations
# Params: None
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS (globals, optional)
# Modifies: http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY, no_proxy, NO_PROXY
#           (all exported)
# Returns: 0 always
# Side-effects: Sets proxy for all subsequent network operations, persists snap proxy
configure_proxy_settings() {
  if [[ -n "${DEVBASE_PROXY_HOST}" && -n "${DEVBASE_PROXY_PORT}" ]]; then
    local proxy_url="http://${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"

    export http_proxy="${proxy_url}"
    export https_proxy="${proxy_url}"
    export HTTP_PROXY="${proxy_url}"
    export HTTPS_PROXY="${proxy_url}"

    if [[ -n "${DEVBASE_NO_PROXY_DOMAINS}" ]]; then
      export no_proxy="${DEVBASE_NO_PROXY_DOMAINS}"
      export NO_PROXY="${DEVBASE_NO_PROXY_DOMAINS}"
    else
      export no_proxy="localhost,127.0.0.1,::1"
      export NO_PROXY="localhost,127.0.0.1,::1"
    fi

    # Configure curl/wget for proxy after exporting proxy vars
    configure_curl_for_proxy

    # Persist snap proxy so it survives reboots (snap ignores env vars)
    if command -v snap &>/dev/null; then
      sudo snap set system proxy.http="${proxy_url}" 2>/dev/null || true
      sudo snap set system proxy.https="${proxy_url}" 2>/dev/null || true
    fi
  fi
}

# Mask credentials in proxy URLs: http://user:pass@host -> http://***:***@host
mask_url_credentials() {
  sed 's|://[^:]*:[^@]*@|://***:***@|'
}
