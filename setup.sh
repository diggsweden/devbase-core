#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

# ============================================================================
# DevBase Installation Setup Script
# ============================================================================

# Guard: Verify running in bash (must check before any bash-specific code)
# Note: BASH_VERSION check must use ${:-} since this runs before our imports
if [ -z "${BASH_VERSION:-}" ]; then
  echo "ERROR: This script must be run with bash, not sourced in another shell."
  echo "Usage: bash setup.sh"
  echo "   or: ./setup.sh"
  exit 1
fi

handle_interrupt() {
  printf "\n\nInstallation cancelled by user (Ctrl+C)\n" >&2
  exit 130
}

trap handle_interrupt INT TERM

# ============================================================================
# OPTIONAL ENVIRONMENT VARIABLES (fail-fast initialization)
# ============================================================================
# Import environment variables that may be set by user/environment before running setup.sh
# Importing here with empty defaults enables fail-fast (set -u) for the rest of the script
#
# For complete documentation: docs/environment.adoc

# User-provided overrides
DEVBASE_CUSTOM_DIR="${DEVBASE_CUSTOM_DIR:-}"      # Custom config directory path
DEVBASE_DEBUG="${DEVBASE_DEBUG:-}"                # Debug mode (set DEVBASE_DEBUG=1 for verbose output)
DEVBASE_THEME="${DEVBASE_THEME:-everforest-dark}" # Theme choice (default: everforest-dark)
DEVBASE_FONT="${DEVBASE_FONT:-monaspace}"         # Font choice (default: monaspace)
export EDITOR="${EDITOR:-nvim}"                   # Default editor: nvim or nano
export VISUAL="${VISUAL:-$EDITOR}"                # Visual editor (defaults to EDITOR)
GIT_EMAIL="${GIT_EMAIL:-@$(hostname)}"            # Git email for non-interactive (default: user@hostname)
GIT_NAME="${GIT_NAME:-DevBase User}"              # Git name for non-interactive (default: DevBase User)
MISE_GITHUB_TOKEN="${MISE_GITHUB_TOKEN:-}"        # GitHub token for mise downloads
SSH_KEY_PASSPHRASE="${SSH_KEY_PASSPHRASE:-}"      # SSH key passphrase

# XDG directories (may be pre-set by user, defaults follow XDG Base Directory spec)
XDG_BIN_HOME="${XDG_BIN_HOME:-${HOME}/.local/bin}" # Not in spec, but follows pattern
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"

# Network configuration (may be set by customization (org.env, see docs))
DEVBASE_PROXY_HOST="${DEVBASE_PROXY_HOST:-}"
DEVBASE_PROXY_PORT="${DEVBASE_PROXY_PORT:-}"
DEVBASE_NO_PROXY_DOMAINS="${DEVBASE_NO_PROXY_DOMAINS:-}"
DEVBASE_REGISTRY_HOST="${DEVBASE_REGISTRY_HOST:-}"
DEVBASE_REGISTRY_PORT="${DEVBASE_REGISTRY_PORT:-}"
DEVBASE_EMAIL_DOMAIN="${DEVBASE_EMAIL_DOMAIN:-}"
DEVBASE_LOCALE="${DEVBASE_LOCALE:-}"
DEVBASE_PYPI_REGISTRY="${DEVBASE_PYPI_REGISTRY:-}"
DEVBASE_NPM_REGISTRY="${DEVBASE_NPM_REGISTRY:-}"
DEVBASE_CYPRESS_REGISTRY="${DEVBASE_CYPRESS_REGISTRY:-}"
DEVBASE_TESTCONTAINERS_PREFIX="${DEVBASE_TESTCONTAINERS_PREFIX:-}"

# Custom configuration paths (set by find_custom_directory() if custom dir exists)
# Initialized here to avoid unbound variable errors with set -u
_DEVBASE_CUSTOM_CERTS=""
_DEVBASE_CUSTOM_HOOKS=""
_DEVBASE_CUSTOM_TEMPLATES=""
_DEVBASE_CUSTOM_SSH=""
_DEVBASE_CUSTOM_PACKAGES=""

# Installation feature flags (user can override via environment)
DEVBASE_INSTALL_DEVTOOLS="${DEVBASE_INSTALL_DEVTOOLS:-true}"  # Install development tools
DEVBASE_INSTALL_LAZYVIM="${DEVBASE_INSTALL_LAZYVIM:-true}"    # Install LazyVim configuration
DEVBASE_INSTALL_JMC="${DEVBASE_INSTALL_JMC:-false}"           # Install Java Mission Control
DEVBASE_INSTALL_INTELLIJ="${DEVBASE_INSTALL_INTELLIJ:-false}" # Install IntelliJ IDEA
DEVBASE_ENABLE_GIT_HOOKS="${DEVBASE_ENABLE_GIT_HOOKS:-true}"  # Enable Git hooks
DEVBASE_ZELLIJ_AUTOSTART="${DEVBASE_ZELLIJ_AUTOSTART:-true}"  # Auto-start Zellij terminal multiplexer

# VSCode configuration flags (defaults set during user preferences collection)
DEVBASE_VSCODE_INSTALL="${DEVBASE_VSCODE_INSTALL:-}"       # Install VSCode (set based on WSL detection)
DEVBASE_VSCODE_EXTENSIONS="${DEVBASE_VSCODE_EXTENSIONS:-}" # Install VSCode extensions

# SSH key management configuration
DEVBASE_SSH_KEY_TYPE="${DEVBASE_SSH_KEY_TYPE:-ed25519}"            # SSH key type: ed25519, ecdsa, ed25519-sk, ecdsa-sk
DEVBASE_SSH_KEY_NAME="${DEVBASE_SSH_KEY_NAME:-id_ed25519_devbase}" # SSH key filename
DEVBASE_SSH_KEY_ACTION="${DEVBASE_SSH_KEY_ACTION:-}"               # SSH key action: new, keep, or import
GENERATED_SSH_PASSPHRASE="${GENERATED_SSH_PASSPHRASE:-false}"      # Flag: passphrase was auto-generated

# Advanced configuration (offline installs, registry overrides)
DEVBASE_DEB_CACHE="${DEVBASE_DEB_CACHE:-}"         # Path to offline .deb package cache
DEVBASE_NO_PROXY_JAVA="${DEVBASE_NO_PROXY_JAVA:-}" # Java-specific no-proxy domains

# Non-interactive mode flag (initialized here, may be set by --non-interactive arg)
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# Dry-run mode flag (skips installation, shows planned steps only)
DEVBASE_DRY_RUN="${DEVBASE_DRY_RUN:-false}"

# Internal flag: show version and exit
SHOW_VERSION="${SHOW_VERSION:-false}"

# TUI mode flag (default: gum, can be overridden with --tui=whiptail)
# Values: "gum", "whiptail" (or "none" for non-interactive mode)
DEVBASE_TUI_MODE="${DEVBASE_TUI_MODE:-gum}"

# ============================================================================
# EXPORTED ENVIRONMENT VARIABLES (see docs/environment.adoc for details)
# ============================================================================
#
# Core Paths (readonly):
#   DEVBASE_ROOT, DEVBASE_LIBS, DEVBASE_DOT, DEVBASE_FILES, DEVBASE_ENVS, DEVBASE_DOCS
#
# Custom Configuration (optional):
#   DEVBASE_CUSTOM_DIR, DEVBASE_CUSTOM_ENV, _DEVBASE_CUSTOM_CERTS,
#   _DEVBASE_CUSTOM_HOOKS, _DEVBASE_CUSTOM_TEMPLATES, _DEVBASE_CUSTOM_SSH
#
# Environment & Network:
#   DEVBASE_ENV, DEVBASE_ENV_FILE, DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT,
#   DEVBASE_NO_PROXY_DOMAINS, DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT, DEVBASE_EMAIL_DOMAIN
#
# Installation Settings:
#   DEVBASE_THEME, DEVBASE_CACHE_DIR, DEVBASE_CONFIG_DIR, DEVBASE_BACKUP_DIR,
#   XDG_* directories
#
# User Preferences (collected during install):
#   DEVBASE_GIT_*, DEVBASE_SSH_*, EDITOR, VISUAL, DEVBASE_INSTALL_*,
#   DEVBASE_ENABLE_GIT_HOOKS, DEVBASE_ZELLIJ_AUTOSTART
#
# For complete documentation with descriptions and examples:
# → docs/environment.adoc
# ============================================================================

# Global variables - set by various functions below
# DevBase paths - set by initialize_devbase_paths()
# Custom paths - set by find_custom_directory()
# Environment vars - set by load_environment_configuration()
# Theme - set by user during installation

# ============================================================================
# ============================================================================

parse_arguments() {
  for arg in "$@"; do
    case $arg in
    --non-interactive)
      NON_INTERACTIVE=true
      export NON_INTERACTIVE=true
      export DEBIAN_FRONTEND=noninteractive
      ;;
    --tui=*)
      local tui_value="${arg#--tui=}"
      case "$tui_value" in
      gum | whiptail)
        DEVBASE_TUI_MODE="$tui_value"
        ;;
      *)
        printf "Error: Invalid TUI mode '%s'. Valid options: gum, whiptail\n" "$tui_value" >&2
        exit 1
        ;;
      esac
      ;;
    --dry-run)
      DEVBASE_DRY_RUN=true
      export DEVBASE_DRY_RUN=true
      ;;
    --version | -v)
      SHOW_VERSION=true
      ;;
    --help | -h)
      printf "Usage: %s [OPTIONS]\n" "$0"
      printf "\n"
      printf "Options:\n"
      printf "  --non-interactive  Run in non-interactive mode (for CI/automation)\n"
      printf "  --dry-run          Print planned steps without installing\n"
      printf "  --tui=<mode>       Set TUI mode: gum (default), whiptail\n"
      printf "  --version, -v      Show version information\n"
      printf "  --help, -h         Show this help message\n"
      exit 0
      ;;
    *)
      printf "Error: Unknown option '%s'\n" "$arg" >&2
      printf "Run '%s --help' for valid options.\n" "$0" >&2
      exit 1
      ;;
    esac
  done
}

# Brief: Initialize core DevBase path variables
# Params: None
# Modifies: DEVBASE_ROOT, DEVBASE_LIBS, DEVBASE_DOT, DEVBASE_FILES, DEVBASE_ENVS,
#           DEVBASE_DOCS (all exported as readonly)
# Returns: 0 always
# Side-effects: None
initialize_devbase_paths() {
  # Get absolute path to devbase root (canonical bash idiom)
  export DEVBASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export DEVBASE_FILES="${DEVBASE_ROOT}/devbase_files"
  export DEVBASE_ENVS="${DEVBASE_ROOT}/environments"
  export DEVBASE_DOCS="${DEVBASE_ROOT}/docs"
  readonly DEVBASE_ROOT DEVBASE_LIBS DEVBASE_DOT DEVBASE_FILES DEVBASE_ENVS DEVBASE_DOCS

  # Determine if running from git clone or release tarball (needed early for display_os_info)
  if git -C "${DEVBASE_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
    export _DEVBASE_FROM_GIT="true"
  else
    export _DEVBASE_FROM_GIT="false"
  fi
}

load_devbase_libraries() {
  source "${DEVBASE_LIBS}/constants.sh"
  source "${DEVBASE_LIBS}/define-colors.sh"
  source "${DEVBASE_LIBS}/utils.sh"
  source "${DEVBASE_LIBS}/ui-helpers.sh"
  source "${DEVBASE_LIBS}/validation.sh"
  source "${DEVBASE_LIBS}/distro.sh"
  source "${DEVBASE_LIBS}/handle-network.sh"
  source "${DEVBASE_LIBS}/process-templates.sh"
  source "${DEVBASE_LIBS}/check-requirements.sh"
  source "${DEVBASE_LIBS}/bootstrap.sh"
  source "${DEVBASE_LIBS}/migrations.sh"
  source "${DEVBASE_LIBS}/install-certificates.sh"
  source "${DEVBASE_LIBS}/configure-ssh-git.sh"
  source "${DEVBASE_LIBS}/configure-git-hooks.sh"
  source "${DEVBASE_LIBS}/configure-completions.sh"
  source "${DEVBASE_LIBS}/configure-shell.sh"
  source "${DEVBASE_LIBS}/configure-services.sh"
  source "${DEVBASE_LIBS}/install-custom.sh"
  source "${DEVBASE_LIBS}/setup-vscode.sh"
  source "${DEVBASE_LIBS}/configure-theme.sh"
}

init_env() {
  initialize_devbase_paths
  load_devbase_libraries
}

resolve_devbase_version() {
  local git_tag=""
  local git_sha="unknown"

  if command -v git &>/dev/null && git -C "${DEVBASE_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
    git_tag=$(git -C "${DEVBASE_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")
    git_sha=$(git -C "${DEVBASE_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  fi

  local devbase_version="0.0.0-dev"
  if [[ -n "$git_tag" ]]; then
    devbase_version="$git_tag"
  fi

  printf "%s %s\n" "$devbase_version" "$git_sha"
}

print_version() {
  local devbase_version
  local git_sha

  read -r devbase_version git_sha <<<"$(resolve_devbase_version)"
  printf "devbase-core %s (%s)\n" "$devbase_version" "$git_sha"
}

show_dry_run_plan() {
  show_progress info "$(ui_message dry_run_plan_header)"
  show_progress info "  - $(ui_message dry_run_plan_preflight)"
  show_progress info "  - $(ui_message dry_run_plan_configuration)"
  show_progress info "  - $(ui_message dry_run_plan_installation)"
  show_progress info "  - $(ui_message dry_run_plan_finalize)"
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
# Returns: 0 always (warnings only, non-fatal)
# Side-effects: Displays warnings if host/port pairs are incomplete, exits on validation error
check_required_config_variables() {
  # Validate proxy configuration
  if [[ -n "${DEVBASE_PROXY_HOST}" ]]; then
    if [[ -z "${DEVBASE_PROXY_PORT}" ]]; then
      show_progress error "DEVBASE_PROXY_HOST is set but DEVBASE_PROXY_PORT is missing"
      show_progress info "Check ${_DEVBASE_ENV_FILE}"
      exit 1
    fi
    validate_not_empty "${DEVBASE_PROXY_HOST}" "DEVBASE_PROXY_HOST" || exit 1
    validate_hostname "${DEVBASE_PROXY_HOST}" "DEVBASE_PROXY_HOST" || exit 1
    validate_port "${DEVBASE_PROXY_PORT}" "DEVBASE_PROXY_PORT" || exit 1
  elif [[ -n "${DEVBASE_PROXY_PORT}" ]]; then
    show_progress error "DEVBASE_PROXY_PORT is set but DEVBASE_PROXY_HOST is missing"
    show_progress info "Check ${_DEVBASE_ENV_FILE}"
    exit 1
  fi

  # Validate registry configuration
  if [[ -n "${DEVBASE_REGISTRY_HOST}" ]]; then
    if [[ -z "${DEVBASE_REGISTRY_PORT}" ]]; then
      show_progress error "DEVBASE_REGISTRY_HOST is set but DEVBASE_REGISTRY_PORT is missing"
      show_progress info "Check ${_DEVBASE_ENV_FILE}"
      exit 1
    fi
    validate_not_empty "${DEVBASE_REGISTRY_HOST}" "DEVBASE_REGISTRY_HOST" || exit 1
    validate_hostname "${DEVBASE_REGISTRY_HOST}" "DEVBASE_REGISTRY_HOST" || exit 1
    validate_port "${DEVBASE_REGISTRY_PORT}" "DEVBASE_REGISTRY_PORT" || exit 1
  elif [[ -n "${DEVBASE_REGISTRY_PORT}" ]]; then
    show_progress error "DEVBASE_REGISTRY_PORT is set but DEVBASE_REGISTRY_HOST is missing"
    show_progress info "Check ${_DEVBASE_ENV_FILE}"
    exit 1
  fi

  # Validate user-provided values for shell metacharacter injection
  validate_email "${GIT_EMAIL}" "GIT_EMAIL" || exit 1
  validate_safe_value "${GIT_NAME}" "GIT_NAME" || exit 1
  validate_safe_value "${DEVBASE_THEME}" "DEVBASE_THEME" || exit 1
  validate_safe_value "${DEVBASE_FONT}" "DEVBASE_FONT" || exit 1

  # Validate registry URLs if set
  if [[ -n "${DEVBASE_NPM_REGISTRY}" ]]; then
    validate_url "${DEVBASE_NPM_REGISTRY}" || exit 1
  fi
  if [[ -n "${DEVBASE_PYPI_REGISTRY}" ]]; then
    validate_url "${DEVBASE_PYPI_REGISTRY}" || exit 1
  fi
  if [[ -n "${DEVBASE_CYPRESS_REGISTRY}" ]]; then
    validate_url "${DEVBASE_CYPRESS_REGISTRY}" || exit 1
  fi
}

# Brief: Display network configuration (proxy, registry, no-proxy)
# Params: None
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_REGISTRY_HOST, DEVBASE_REGISTRY_PORT, DEVBASE_NO_PROXY_DOMAINS (globals)
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
# Uses: DEVBASE_EMAIL_DOMAIN, DEVBASE_LOCALE (globals)
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
# Uses: _DEVBASE_CUSTOM_HOOKS (global), validate_custom_dir (function)
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
# Uses: _DEVBASE_CUSTOM_SSH, DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT (globals)
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
# Uses: DEVBASE_CUSTOM_DIR (global)
# Returns: 0 always
# Side-effects: Displays validation status and configuration info
validate_custom_config() {
  [[ -z "${DEVBASE_CUSTOM_DIR}" ]] && return 0

  show_progress step "Validating custom configuration"

  check_required_config_variables
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
# Params: None
# Uses: NON_INTERACTIVE, _DEVBASE_TEMP, DEVBASE_DEB_CACHE, _DEVBASE_ENV (globals)
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads and installs gum if not present
# Note: This runs early in setup before libs/install-custom.sh is loaded, so
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

# Brief: Persist devbase repos to user data directory for update support
# Params: None
# Uses: DEVBASE_ROOT, DEVBASE_CUSTOM_DIR, _DEVBASE_FROM_GIT, XDG_DATA_HOME (globals)
# Returns: 0 on success
# Side-effects: Clones/updates repos to ~/.local/share/devbase/{core,custom}
persist_devbase_repos() {
  local core_dest="$XDG_DATA_HOME/devbase/core"
  local custom_dest="$XDG_DATA_HOME/devbase/custom"

  mkdir -p "$(dirname "$core_dest")"

  # Persist core repo
  if [[ "$_DEVBASE_FROM_GIT" == "true" ]]; then
    local current_remote
    local current_tag
    local core_ref
    current_remote=$(git -C "$DEVBASE_ROOT" remote get-url origin 2>/dev/null || echo "")
    current_tag=$(git -C "$DEVBASE_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "main")
    core_ref="${DEVBASE_CORE_REF:-$current_tag}"

    if [[ -z "$current_remote" ]]; then
      show_progress warning "Could not determine core remote URL - skipping repo persistence"
      return 1
    fi

    if [[ ! -d "$core_dest/.git" ]]; then
      show_progress step "Cloning devbase-core to persistent location..."
      if git clone --depth 1 --branch "$core_ref" "$current_remote" "$core_dest" 2>/dev/null; then
        show_progress success "Core repo cloned to $core_dest"
      else
        # Fallback: clone without branch (tag might not exist on fresh clone)
        git clone --depth 1 "$current_remote" "$core_dest"
        git -C "$core_dest" fetch --depth 1 --tags --quiet

        if [[ -n "${DEVBASE_CORE_REF:-}" ]]; then
          if git -C "$core_dest" fetch --depth 1 origin "+refs/heads/*:refs/remotes/origin/*" --quiet 2>/dev/null &&
            git -C "$core_dest" checkout "origin/$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          elif git -C "$core_dest" fetch --depth 1 origin "+refs/tags/$core_ref:refs/tags/$core_ref" --quiet 2>/dev/null &&
            git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          else
            show_progress warning "Could not checkout core ref: $core_ref"
          fi
        else
          if git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo cloned to $core_dest"
          else
            show_progress success "Core repo cloned to $core_dest"
          fi
        fi
      fi
    else
      # Already exists - update to current tag or requested ref
      show_progress step "Updating persistent core repo..."
      if [[ -n "${DEVBASE_CORE_REF:-}" ]]; then
        if git -C "$core_dest" fetch --depth 1 origin "+refs/heads/*:refs/remotes/origin/*" --quiet 2>/dev/null &&
          git -C "$core_dest" checkout "origin/$core_ref" --quiet 2>/dev/null; then
          show_progress success "Core repo updated at $core_dest"
        elif git -C "$core_dest" fetch --depth 1 origin "+refs/tags/$core_ref:refs/tags/$core_ref" --quiet 2>/dev/null &&
          git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
          show_progress success "Core repo updated at $core_dest"
        else
          show_progress warning "Could not checkout core ref: $core_ref"
        fi
      else
        if git -C "$core_dest" fetch --depth 1 origin "$core_ref" --quiet 2>/dev/null ||
          git -C "$core_dest" fetch --depth 1 --tags --quiet; then
          if git -C "$core_dest" checkout "$core_ref" --quiet 2>/dev/null; then
            show_progress success "Core repo updated at $core_dest"
          else
            show_progress success "Core repo updated at $core_dest"
          fi
        fi
      fi
    fi
  else
    show_progress info "Not running from git clone - skipping core repo persistence"
  fi

  # Persist custom config repo (if it's a git repo)
  if [[ -n "${DEVBASE_CUSTOM_DIR:-}" ]] && git -C "$DEVBASE_CUSTOM_DIR" rev-parse --git-dir &>/dev/null; then
    local custom_remote
    custom_remote=$(git -C "$DEVBASE_CUSTOM_DIR" remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$custom_remote" ]]; then
      if [[ ! -d "$custom_dest/.git" ]]; then
        show_progress step "Cloning custom config to persistent location..."
        git clone --depth 1 "$custom_remote" "$custom_dest"
        show_progress success "Custom config cloned to $custom_dest"
      else
        show_progress step "Updating persistent custom config..."
        git -C "$custom_dest" fetch --depth 1 --quiet
        git -C "$custom_dest" reset --hard origin/HEAD --quiet 2>/dev/null ||
          git -C "$custom_dest" reset --hard origin/main --quiet 2>/dev/null || true
        show_progress success "Custom config updated at $custom_dest"
      fi
    fi
  fi

  return 0
}

run_installation() {
  # Run the main installation script
  _INSTALL_SCRIPT="${DEVBASE_LIBS}/install.sh"

  if [[ -f "$_INSTALL_SCRIPT" ]]; then
    # Only export what child processes actually need
    # Proxy variables already exported above if configured
    export DEVBASE_ENV="$_DEVBASE_ENV"           # Environment type (ubuntu/wsl-ubuntu)
    export DEVBASE_ENV_FILE="$_DEVBASE_ENV_FILE" # Path to env file

    # Source the main installation script (not bash) to keep arrays available
    # shellcheck disable=SC1090 # Dynamic source path
    source "$_INSTALL_SCRIPT"
  else
    die "Main installation script not found: ${_INSTALL_SCRIPT}"
  fi
}

main() {
  parse_arguments "$@"
  init_env

  if [[ "${SHOW_VERSION}" == "true" ]]; then
    print_version
    return 0
  fi

  run_bootstrap || return 1

  if [[ "${DEVBASE_DRY_RUN}" == "true" ]]; then
    show_dry_run_plan
    show_progress info "$(ui_message dry_run_install_skip)"
    return 0
  fi

  run_installation || return 1

  # Run migrations after successful installation to clean up legacy files
  if ! run_migrations; then
    show_progress warning "Migrations failed - continuing"
  fi
}

main "$@"
