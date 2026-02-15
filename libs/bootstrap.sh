#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

show_welcome_banner() {
  local devbase_version
  local git_sha

  read -r devbase_version git_sha <<<"$(resolve_devbase_version)"

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    echo
    gum style \
      --foreground 212 \
      --border double \
      --border-foreground 212 \
      --padding "1 4" \
      --margin "1 0" \
      --align center \
      "DevBase Core Installation" \
      "" \
      "Version: $devbase_version ($git_sha)" \
      "Started: $(date +"%H:%M:%S")"
    echo
    gum style --foreground 240 --align center \
      "Development environment setup wizard"
    gum style --foreground 240 \
      "j/k navigate  SPACE toggle  ENTER select  Ctrl+C cancel"
    echo
  else
    # Whiptail mode (default) - show welcome infobox
    clear
    whiptail --backtitle "$WT_BACKTITLE" --title "DevBase Core Installation" \
      --infobox "Version: $devbase_version ($git_sha)\nStarted: $(date +"%H:%M:%S")\n\nInitializing..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
  fi
}

show_os_info() {
  local os_name env_type install_type
  os_name=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
  env_type=$([[ "${_DEVBASE_ENV:-}" == "wsl-ubuntu" ]] && echo "WSL" || echo "Native Linux")
  install_type=$([[ "${_DEVBASE_FROM_GIT:-}" == "true" ]] && echo "Git repository" || echo "Downloaded")

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum style --foreground 240 "System Information"
    echo "  OS:           $os_name"
    echo "  Environment:  $env_type"
    echo "  Installation: $install_type"
    echo "  User:         $USER"
    echo "  Home:         $HOME"
    echo
  else
    # Whiptail mode - show system info infobox
    whiptail --backtitle "$WT_BACKTITLE" --title "System Information" \
      --infobox "OS: $os_name\nEnvironment: $env_type\nUser: $USER\n\nLoading configuration..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
    sleep 1
  fi
}

show_repository_info() {
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    # Silent in whiptail mode - info shown in whiptail dialogs
    return 0
  fi
  # shellcheck disable=SC2153 # DEVBASE_ROOT set by init_env
  echo "  Running from: $DEVBASE_ROOT"
  echo
}

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

load_environment_configuration() {
  # Trust model: org.env is provided by the org's devbase-custom-config repo,
  # which the user explicitly opted into. Protected vars (DEVBASE_ROOT, etc.)
  # are rejected below to prevent privilege escalation via the env file.

  # Determine environment file to use
  if [[ -n "${DEVBASE_CUSTOM_DIR}" ]] && [[ -f "${DEVBASE_CUSTOM_DIR}/config/org.env" ]]; then
    _DEVBASE_ENV_FILE="${DEVBASE_CUSTOM_DIR}/config/org.env"
    show_progress step "Using custom environment: ${_DEVBASE_ENV_FILE}"
  else
    _DEVBASE_ENV_FILE="${DEVBASE_ENVS}/default.env"
    show_progress step "Using default environment: ${_DEVBASE_ENV_FILE}"
  fi

  # These should only be set by the installation script
  local protected_vars=(DEVBASE_ROOT DEVBASE_LIBS DEVBASE_DOT DEVBASE_FILES DEVBASE_ENVS DEVBASE_DOCS)
  for var in "${protected_vars[@]}"; do
    if grep -q "^${var}=" "${_DEVBASE_ENV_FILE}" 2>/dev/null; then
      printf "  %b%s%b Environment file attempts to override protected variable: %s\n" \
        "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "${var}" >&2
      die "Please remove ${var} from ${_DEVBASE_ENV_FILE}"
    fi
  done

  # NOTE: This is expected to set org-specific variables like:
  #   DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS,
  #   DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT, etc.
  # shellcheck disable=SC1090 # Dynamic source path
  source "${_DEVBASE_ENV_FILE}"

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

# Brief: Bootstrap gum TUI tool for interactive setup
# Uses: get_deb_arch, get_rpm_arch, show_progress, verify_checksum_value (functions)
# Returns: 0 if gum is available or installed, 1 otherwise
# Side-effects: Downloads and installs gum if missing
# Note: This runs before most libs are loaded to ensure UI is available;
# it intentionally duplicates some download/arch logic from install-custom.sh.
# The libs are not yet sourced at bootstrap time.
bootstrap_gum() {
  # Skip in non-interactive mode - gum not needed
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    return 0
  fi

  # Already installed - nothing to do
  if command -v gum &>/dev/null; then
    local current_version
    current_version=$(gum --version 2>/dev/null | head -1 | awk '{print $3}')
    show_progress success "gum available (${current_version})"
    return 0
  fi

  show_progress step "Installing gum for interactive setup..."

  # Version and architecture
  local version="0.17.0" # renovate: datasource=github-releases depName=charmbracelet/gum
  local arch
  arch=$(get_deb_arch) || {
    show_progress warning "Could not find TUI component gum (unsupported architecture: $(uname -m)), using whiptail as backup"
    return 1
  }

  # Detect package format based on environment
  local pkg_format="deb"
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora) pkg_format="rpm" ;;
  esac

  # For rpm, architecture naming differs
  local rpm_arch="$arch"
  if [[ "$pkg_format" == "rpm" ]]; then
    rpm_arch=$(get_rpm_arch)
  fi

  local package_name
  local gum_url
  if [[ "$pkg_format" == "deb" ]]; then
    package_name="gum_${version}_${arch}.deb"
  else
    package_name="gum-${version}.${rpm_arch}.rpm"
  fi
  gum_url="https://github.com/charmbracelet/gum/releases/download/v${version}/${package_name}"
  local checksums_url="https://github.com/charmbracelet/gum/releases/download/v${version}/checksums.txt"

  # Create temp directory if not set
  local temp_dir="${_DEVBASE_TEMP:-$(mktemp -d)}"
  local gum_pkg="${temp_dir}/${package_name}"

  # Check cache first (support both DEB and RPM cache paths)
  local cache_dir="${DEVBASE_DEB_CACHE:-}"
  if [[ -n "$cache_dir" ]] && [[ -f "${cache_dir}/${package_name}" ]]; then
    show_progress info "Using cached gum package"
    cp "${cache_dir}/${package_name}" "$gum_pkg"
  else
    # Download gum
    if ! curl -fL --progress-bar "$gum_url" -o "$gum_pkg" 2>/dev/null; then
      show_progress warning "Could not find TUI component gum (download failed), using whiptail as backup"
      return 1
    fi

    # Fetch and verify checksum using shared verification logic
    local expected_checksum=""
    if expected_checksum=$(get_checksum_from_manifest "$checksums_url" "$package_name" "30"); then
      if ! verify_checksum_value "$gum_pkg" "$expected_checksum"; then
        show_progress warning "Could not find TUI component gum (checksum failed), using whiptail as backup"
        return 1
      fi
    else
      show_progress warning "Could not verify gum checksum - continuing anyway"
    fi

    # Cache for future use
    if [[ -n "$cache_dir" ]]; then
      mkdir -p "$cache_dir"
      cp "$gum_pkg" "${cache_dir}/${package_name}"
    fi
  fi

  # Install gum based on package format
  if [[ -f "$gum_pkg" ]]; then
    if [[ "$pkg_format" == "deb" ]]; then
      if sudo dpkg -i "$gum_pkg" >/dev/null 2>&1; then
        show_progress success "gum installed (${version})"
        return 0
      else
        # Try to fix dependencies
        sudo apt-get install -f -y -q >/dev/null 2>&1 || true
        if command -v gum &>/dev/null; then
          show_progress success "gum installed (${version})"
          return 0
        fi
      fi
    else
      # RPM installation (try dnf, then rpm directly)
      if sudo dnf install -y "$gum_pkg" >/dev/null 2>&1 ||
        sudo rpm -i "$gum_pkg" >/dev/null 2>&1; then
        show_progress success "gum installed (${version})"
        return 0
      fi
    fi
  fi

  show_progress warning "Could not find TUI component gum, could not install, using whiptail as backup"
  return 1
}

# Brief: Determine which TUI mode to use and bootstrap if needed
# Uses: DEVBASE_TUI_MODE, NON_INTERACTIVE, bootstrap_gum (globals/functions)
# Returns: 0 on success, 1 on failure
# Sets DEVBASE_TUI_MODE to: "gum", "whiptail" (or "none" for NON_INTERACTIVE)
# Respects --tui=<mode> flag if set by parse_arguments()
select_tui_mode() {
  # Non-interactive doesn't need TUI
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    export DEVBASE_TUI_MODE="none"
    return 0
  fi

  # Handle explicit --tui=whiptail request (no fallback)
  if [[ "${DEVBASE_TUI_MODE}" == "whiptail" ]]; then
    if command -v whiptail &>/dev/null; then
      export DEVBASE_TUI_MODE="whiptail"
      return 0
    else
      printf "Error: whiptail requested but not installed.\n" >&2
      case "${_DEVBASE_ENV:-ubuntu}" in
      fedora)
        printf "Install with: sudo dnf install newt\n" >&2
        ;;
      *)
        printf "Install with: sudo apt-get install whiptail\n" >&2
        ;;
      esac
      exit 1
    fi
  fi

  # Handle --tui=gum (default) - try gum, fall back to whiptail
  if [[ "${DEVBASE_TUI_MODE}" == "gum" ]]; then
    if command -v gum &>/dev/null || bootstrap_gum; then
      export DEVBASE_TUI_MODE="gum"
      return 0
    fi

    # Gum failed - fall back to whiptail
    if command -v whiptail &>/dev/null; then
      show_progress info "Using whiptail as TUI (gum not available)"
      export DEVBASE_TUI_MODE="whiptail"
      return 0
    fi
  fi

  # Neither available - exit with helpful message
  printf "\n"
  printf "Error: No TUI component available.\n" >&2
  printf "\n" >&2
  printf "devbase requires either 'gum' or 'whiptail' for the interactive installer.\n" >&2
  printf "\n" >&2
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora)
    printf "Install whiptail with:\n" >&2
    printf "  sudo dnf install newt\n" >&2
    ;;
  *)
    printf "Install whiptail with:\n" >&2
    printf "  sudo apt-get install whiptail\n" >&2
    ;;
  esac
  printf "\n" >&2
  printf "Then run this script again.\n" >&2
  exit 1
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

# Brief: Bootstrap installation prerequisites and UI
# Params: None
# Uses: detect_environment, find_custom_directory, load_environment_configuration,
#       configure_proxy_settings, install_certificates, select_tui_mode,
#       show_welcome_banner, show_os_info, check_required_tools,
#       show_repository_info, test_generic_network_connectivity,
#       validate_custom_config, run_pre_install_hook, set_default_values
# Returns: 0 on success
# Side-effects: Configures env, UI, and validations before install
run_bootstrap() {
  require_env DEVBASE_ROOT DEVBASE_LIBS || return 1

  # Minimal pre-TUI setup: detect environment and configure network
  detect_environment || return 1
  find_custom_directory || return 1
  load_environment_configuration || return 1
  configure_proxy_settings || return 1

  if [[ "${DEVBASE_DRY_RUN}" == "true" ]]; then
    show_progress info "$(ui_message dry_run_bootstrap_skip)"
    return 0
  fi

  # Install certificates before any downloads (gum/mise) to avoid TLS issues
  install_certificates || return 1

  # Bootstrap TUI early (needs network for gum download)
  # This enables gum/whiptail for all subsequent UI
  show_progress info "Preparing installer UI..."
  select_tui_mode || return 1

  # Now show welcome and run checks using TUI
  show_welcome_banner
  show_os_info
  check_required_tools || return 1
  show_repository_info

  test_generic_network_connectivity
  validate_custom_config || return 1
  run_pre_install_hook
  set_default_values

  return 0
}

export -f run_bootstrap
