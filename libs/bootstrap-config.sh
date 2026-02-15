#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

validate_custom_directory() {
  local dir="$1"

  local required_dirs=("config")

  for subdir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir/$subdir" ]]; then
      return 1
    fi
  done

  if [[ ! -f "$dir/config/org.env" ]]; then
    return 1
  fi

  return 0
}

find_custom_directory() {
  require_env DEVBASE_ROOT HOME || return 1
  # shellcheck disable=SC2153 # DEVBASE_ROOT set by init_env
  local candidates=(
    "${DEVBASE_CUSTOM_DIR}" # Imported at top - empty if user didn't set it
    "$DEVBASE_ROOT/../devbase-custom-config"
    "$DEVBASE_ROOT/devbase-custom-config"
    "$HOME/.local/share/devbase/custom" # Persisted custom config from previous install
  )

  for path in "${candidates[@]}"; do
    [[ -d "$path" ]] || continue

    local fullpath
    fullpath=$(cd "$path" && pwd) || continue

    if ! validate_custom_directory "$fullpath"; then
      # Skip silently if directory is empty (leftover from previous install)
      # Only warn if directory has some content but incomplete structure
      if [[ -n "$(ls -A "$fullpath" 2>/dev/null)" ]]; then
        show_progress info "Skipping incomplete custom config: $fullpath"
      fi
      if [[ -n "${DEVBASE_CUSTOM_DIR}" && "$fullpath" == "$DEVBASE_CUSTOM_DIR" ]]; then
        DEVBASE_CUSTOM_DIR=""
      fi
      continue
    fi

    show_progress step "Using custom configuration: $fullpath"
    export DEVBASE_CUSTOM_DIR="$fullpath"
    export DEVBASE_CUSTOM_ENV="$fullpath/config"
    export _DEVBASE_CUSTOM_CERTS="$fullpath/certificates"
    export _DEVBASE_CUSTOM_HOOKS="$fullpath/hooks"
    export _DEVBASE_CUSTOM_TEMPLATES="$fullpath/templates"
    export _DEVBASE_CUSTOM_SSH="$fullpath/ssh"
    export _DEVBASE_CUSTOM_PACKAGES="$fullpath/packages"

    # Export flag for templates if custom cert directory has at least one .crt file
    if [[ -d "$fullpath/certificates" ]] && compgen -G "$fullpath/certificates/*.crt" >/dev/null 2>&1; then
      export DEVBASE_CUSTOM_CERTS="true"
    fi

    # Debug output if DEVBASE_DEBUG is set (see docs/environment.adoc)
    if [[ "${DEVBASE_DEBUG}" == "1" ]]; then
      show_progress info "DEVBASE_CUSTOM_DIR=${DEVBASE_CUSTOM_DIR}"
      show_progress info "DEVBASE_CUSTOM_ENV=${DEVBASE_CUSTOM_ENV}"
      show_progress info "_DEVBASE_CUSTOM_CERTS=${_DEVBASE_CUSTOM_CERTS}"
      show_progress info "_DEVBASE_CUSTOM_HOOKS=${_DEVBASE_CUSTOM_HOOKS}"
      show_progress info "_DEVBASE_CUSTOM_TEMPLATES=${_DEVBASE_CUSTOM_TEMPLATES}"
      show_progress info "_DEVBASE_CUSTOM_SSH=${_DEVBASE_CUSTOM_SSH}"
      show_progress info "_DEVBASE_CUSTOM_PACKAGES=${_DEVBASE_CUSTOM_PACKAGES}"
    fi

    return 0
  done

  # If we get here, no custom directory was found
  show_progress info "No custom directory found (using default configuration)"
  show_progress info "Searched locations:"
  [[ -n "${DEVBASE_CUSTOM_DIR}" ]] && show_progress info "  • \$DEVBASE_CUSTOM_DIR: ${DEVBASE_CUSTOM_DIR}"
  show_progress info "  • $DEVBASE_ROOT/../devbase-custom-config"
  show_progress info "  • $DEVBASE_ROOT/devbase-custom-config"
  show_progress info "  • $HOME/.local/share/devbase/custom"
}

resolve_environment_file() {
  require_env DEVBASE_ENVS || return 1

  if [[ -n "${DEVBASE_CUSTOM_DIR}" ]] && [[ -f "${DEVBASE_CUSTOM_DIR}/config/org.env" ]]; then
    echo "${DEVBASE_CUSTOM_DIR}/config/org.env"
    return 0
  fi

  echo "${DEVBASE_ENVS}/default.env"
  return 0
}

select_environment_file() {
  local env_file
  env_file=$(resolve_environment_file) || return 1

  _DEVBASE_ENV_FILE="$env_file"

  if [[ -n "${DEVBASE_CUSTOM_DIR}" ]] && [[ "${_DEVBASE_ENV_FILE}" == "${DEVBASE_CUSTOM_DIR}/config/org.env" ]]; then
    show_progress step "Using custom environment: ${_DEVBASE_ENV_FILE}"
  else
    show_progress step "Using default environment: ${_DEVBASE_ENV_FILE}"
  fi

  if [[ ! -f "${_DEVBASE_ENV_FILE}" ]]; then
    show_progress error "Environment file not found: ${_DEVBASE_ENV_FILE}"
    return 1
  fi

  return 0
}

load_environment_configuration() {
  # Trust model: org.env is provided by the org's devbase-custom-config repo,
  # which the user explicitly opted into. Protected vars (DEVBASE_ROOT, etc.)
  # are rejected below to prevent privilege escalation via the env file.

  select_environment_file || return 1

  # These should only be set by the installation script
  local protected_vars=(DEVBASE_ROOT DEVBASE_LIBS DEVBASE_DOT DEVBASE_FILES DEVBASE_ENVS DEVBASE_DOCS)
  for var in "${protected_vars[@]}"; do
    if grep -q "^${var}=" "${_DEVBASE_ENV_FILE}" 2>/dev/null; then
      printf "  %b%s%b Environment file attempts to override protected variable: %s\n" \
        "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "${var}" >&2
      show_progress error "Please remove ${var} from ${_DEVBASE_ENV_FILE}"
      return 1
    fi
  done

  # NOTE: This is expected to set org-specific variables like:
  #   DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS,
  #   DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT, etc.
  # shellcheck disable=SC1090 # Dynamic source path
  source "${_DEVBASE_ENV_FILE}"

  return 0
}

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

# Brief: Check if required configuration variables are set
# Params: None
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT, _DEVBASE_ENV_FILE (globals)
# Returns: 0 if valid, 1 if validation fails
# Side-effects: Displays warnings if host/port pairs are incomplete
check_required_config_variables() {
  require_env _DEVBASE_ENV_FILE || return 1

  # Validate proxy configuration
  if [[ -n "${DEVBASE_PROXY_HOST}" ]]; then
    if [[ -z "${DEVBASE_PROXY_PORT}" ]]; then
      show_progress error "DEVBASE_PROXY_HOST is set but DEVBASE_PROXY_PORT is missing"
      show_progress info "Check ${_DEVBASE_ENV_FILE}"
      return 1
    fi
    validate_not_empty "${DEVBASE_PROXY_HOST}" "DEVBASE_PROXY_HOST" || return 1
    validate_hostname "${DEVBASE_PROXY_HOST}" "DEVBASE_PROXY_HOST" || return 1
    validate_port "${DEVBASE_PROXY_PORT}" "DEVBASE_PROXY_PORT" || return 1
  elif [[ -n "${DEVBASE_PROXY_PORT}" ]]; then
    show_progress error "DEVBASE_PROXY_PORT is set but DEVBASE_PROXY_HOST is missing"
    show_progress info "Check ${_DEVBASE_ENV_FILE}"
    return 1
  fi

  # Validate registry configuration
  if [[ -n "${DEVBASE_REGISTRY_HOST}" ]]; then
    if [[ -z "${DEVBASE_REGISTRY_PORT}" ]]; then
      show_progress error "DEVBASE_REGISTRY_HOST is set but DEVBASE_REGISTRY_PORT is missing"
      show_progress info "Check ${_DEVBASE_ENV_FILE}"
      return 1
    fi
    validate_not_empty "${DEVBASE_REGISTRY_HOST}" "DEVBASE_REGISTRY_HOST" || return 1
    validate_hostname "${DEVBASE_REGISTRY_HOST}" "DEVBASE_REGISTRY_HOST" || return 1
    validate_port "${DEVBASE_REGISTRY_PORT}" "DEVBASE_REGISTRY_PORT" || return 1
  elif [[ -n "${DEVBASE_REGISTRY_PORT}" ]]; then
    show_progress error "DEVBASE_REGISTRY_PORT is set but DEVBASE_REGISTRY_HOST is missing"
    show_progress info "Check ${_DEVBASE_ENV_FILE}"
    return 1
  fi

  # Validate user-provided values for shell metacharacter injection
  validate_email "${GIT_EMAIL}" "GIT_EMAIL" || return 1
  validate_safe_value "${GIT_NAME}" "GIT_NAME" || return 1
  validate_safe_value "${DEVBASE_THEME}" "DEVBASE_THEME" || return 1
  validate_safe_value "${DEVBASE_FONT}" "DEVBASE_FONT" || return 1

  # Validate registry URLs if set
  if [[ -n "${DEVBASE_NPM_REGISTRY}" ]]; then
    validate_url "${DEVBASE_NPM_REGISTRY}" || return 1
  fi
  if [[ -n "${DEVBASE_PYPI_REGISTRY}" ]]; then
    validate_url "${DEVBASE_PYPI_REGISTRY}" || return 1
  fi
  if [[ -n "${DEVBASE_CYPRESS_REGISTRY}" ]]; then
    validate_url "${DEVBASE_CYPRESS_REGISTRY}" || return 1
  fi
}

# Brief: Display network configuration (proxy, registry, no-proxy)
# Params: None
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT (globals)
# Returns: 0 always
# Side-effects: Displays info messages
display_network_configuration() {
  if [[ -n "${DEVBASE_PROXY_HOST}" && -n "${DEVBASE_PROXY_PORT}" ]]; then
    show_progress info "Proxy: ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
  fi

  if [[ -n "${DEVBASE_REGISTRY_HOST}" && -n "${DEVBASE_REGISTRY_PORT}" ]]; then
    show_progress info "Registry: ${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT}"
  fi

  [[ -n "${DEVBASE_NO_PROXY_DOMAINS}" ]] &&
    show_progress info "No-proxy domains: ${DEVBASE_NO_PROXY_DOMAINS}"
}

# Brief: Display custom organization settings (email domain, locale)
# Params: None
# Uses: DEVBASE_EMAIL_DOMAIN, DEVBASE_LOCALE
# Returns: 0 always
# Side-effects: Displays info messages
display_custom_settings() {
  if [[ -n "${DEVBASE_EMAIL_DOMAIN}" ]] && [[ "${DEVBASE_EMAIL_DOMAIN}" != "@" ]]; then
    show_progress info "Email domain: ${DEVBASE_EMAIL_DOMAIN} (pre-fills Git config)"
  fi

  if [[ -n "${DEVBASE_LOCALE}" ]] && [[ "${DEVBASE_LOCALE}" != "en_US.UTF-8" ]]; then
    show_progress info "Locale: ${DEVBASE_LOCALE}"
  fi
}

# Brief: Display available custom hook scripts
# Params: None
# Uses: _DEVBASE_CUSTOM_HOOKS (global)
# Returns: 0 always
# Side-effects: Displays info message if hooks found
display_custom_hooks() {
  validate_custom_dir "_DEVBASE_CUSTOM_HOOKS" "Custom hooks directory" || return 0

  local hooks=()
  for hook in pre-install post-configuration post-install; do
    if validate_custom_file "_DEVBASE_CUSTOM_HOOKS" "${hook}.sh" "Custom hook"; then
      hooks+=("${hook}.sh")
    fi
  done

  [[ ${#hooks[@]} -gt 0 ]] && show_progress info "Custom hooks: ${hooks[*]}"
}

# Brief: Display SSH hosts configured with proxy
# Params: None
# Uses: _DEVBASE_CUSTOM_SSH, DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT
# Returns: 0 always
# Side-effects: Displays info message if proxied hosts found
display_ssh_proxy_configuration() {
  validate_custom_file "_DEVBASE_CUSTOM_SSH" "custom.config" "Custom SSH config" || return 0

  local ssh_proxied_hosts
  ssh_proxied_hosts=$(awk '/^Host / {host=$2} /ProxyCommand/ && host {print host; host=""}' \
    "${_DEVBASE_CUSTOM_SSH}/custom.config" 2>/dev/null |
    paste -sd "," -)

  if [[ -n "$ssh_proxied_hosts" ]] && [[ -n "${DEVBASE_PROXY_HOST}" && -n "${DEVBASE_PROXY_PORT}" ]]; then
    show_progress info "SSH proxy: ${ssh_proxied_hosts} → ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
  fi
}

# Brief: Validate and display custom organization configuration
# Params: None
# Uses: DEVBASE_CUSTOM_DIR, DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT (globals)
# Returns: 0 always
# Side-effects: Displays validation status and configuration info
validate_custom_config() {
  [[ -z "${DEVBASE_CUSTOM_DIR}" ]] && return 0

  show_progress step "Validating custom configuration"

  check_required_config_variables || return 1
  display_network_configuration
  display_custom_settings
  display_custom_hooks
  display_ssh_proxy_configuration
}

run_pre_install_hook() {
  # Run pre-install hook if it exists (organization-specific)
  if validate_custom_file "_DEVBASE_CUSTOM_HOOKS" "pre-install.sh" "Pre-install hook"; then
    show_progress step "Running pre-install hook"
    # Run in subprocess for isolation (hooks can't pollute main script)
    bash "${_DEVBASE_CUSTOM_HOOKS}/pre-install.sh" || {
      show_progress warning "Pre-install hook failed, continuing anyway"
    }
  fi
}

test_generic_network_connectivity() {
  # Test generic network connectivity AFTER proxy is configured
  # This applies to all installations (with or without custom config)
  tui_blank_line
  show_progress step "Testing network connectivity"

  if ! check_network_connectivity; then
    show_progress warning "Network connectivity check failed - continuing anyway"
    show_progress info "Installation may fail if network access is required"
  fi
}

set_default_values() {
  # Export variables that were initialized in IMPORT section with defaults
  export DEVBASE_PROXY_HOST DEVBASE_PROXY_PORT DEVBASE_NO_PROXY_DOMAINS
  export DEVBASE_REGISTRY_HOST DEVBASE_REGISTRY_PORT
  export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_BIN_HOME
  export DEVBASE_THEME DEVBASE_FONT

  # Define DevBase directories using XDG variables
  export DEVBASE_CACHE_DIR="${XDG_CACHE_HOME}/devbase"
  export DEVBASE_CONFIG_DIR="${XDG_CONFIG_HOME}/devbase"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"

  # Debug output if DEVBASE_DEBUG environment variable is set
  if [[ "${DEVBASE_DEBUG}" == "1" ]]; then
    show_progress info "Debug mode enabled"
    show_progress info "DEVBASE_ROOT=${DEVBASE_ROOT}"
    # shellcheck disable=SC2153 # _DEVBASE_FROM_GIT set in this function before this point
    show_progress info "_DEVBASE_FROM_GIT=${_DEVBASE_FROM_GIT}"
    show_progress info "_DEVBASE_ENV_FILE=${_DEVBASE_ENV_FILE}"
    # shellcheck disable=SC2153 # _DEVBASE_ENV set by detect_environment() before this function is called
    show_progress info "_DEVBASE_ENV=${_DEVBASE_ENV}"
    if [[ -n "${DEVBASE_PROXY_HOST}" && -n "${DEVBASE_PROXY_PORT}" ]]; then
      show_progress info "Proxy configured: ${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"
    fi
  fi
}
