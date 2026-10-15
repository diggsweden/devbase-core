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

  # Optional organization registries use the clients' native environment.
  local mapping source_var target_var
  for mapping in \
    DEVBASE_NPM_REGISTRY:NPM_CONFIG_REGISTRY \
    DEVBASE_CYPRESS_REGISTRY:CYPRESS_DOWNLOAD_MIRROR \
    DEVBASE_GO_REGISTRY:GOPROXY \
    DEVBASE_GO_SUMDB:GOSUMDB \
    DEVBASE_RUSTUP_DIST_SERVER:RUSTUP_DIST_SERVER \
    DEVBASE_RUSTUP_UPDATE_ROOT:RUSTUP_UPDATE_ROOT \
    DEVBASE_MISE_PYTHON_COMPILE:MISE_PYTHON_COMPILE \
    DEVBASE_MISE_URL_REPLACEMENTS:MISE_URL_REPLACEMENTS; do
    source_var="${mapping%%:*}"
    target_var="${mapping#*:}"
    if [[ -n "${!source_var:-}" ]]; then
      export "${target_var}=${!source_var}"
    fi
  done
  if [[ -n "${DEVBASE_MISE_URL_REPLACEMENTS:-}" ]]; then
    # Metadata mirrors serve reads, not mise's installation-statistics POSTs.
    export MISE_USE_VERSIONS_HOST_TRACK=false
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
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS,
#       HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy (globals, optional)
# Modifies: http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY, no_proxy, NO_PROXY
#           NODE_USE_ENV_PROXY (all exported; preserves an explicit Node setting)
# Returns: 0 always
# Side-effects: Sets proxy for all subsequent network operations
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
  fi

  # Node's built-in clients require opt-in to use proxy environment variables.
  if [[ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" && ! -v NODE_USE_ENV_PROXY ]]; then
    export NODE_USE_ENV_PROXY=1
  fi
}

# Mask credentials in proxy URLs: http://user:pass@host -> http://***:***@host
mask_url_credentials() {
  # Mask every userinfo occurrence on the line, with or without a password.
  # Excluding / from both classes keeps a path containing @ untouched.
  sed -E 's#://[^:/@[:space:]]*:[^@/[:space:]]*@#://***:***@#g; s#://[^:/@[:space:]]+@#://***@#g'
}
