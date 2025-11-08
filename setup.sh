#!/usr/bin/env bash
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
# IMPORT OPTIONAL ENVIRONMENT VARIABLES (fail-fast initialization)
# ============================================================================
# Import environment variables that may be set by user/environment before running setup.sh
# Importing here with empty defaults enables fail-fast (set -u) for the rest of the script
# Any typo in variable names will cause immediate crash instead of silent empty string
#
# For complete documentation: docs/environment.adoc

# User-provided overrides
DEVBASE_CUSTOM_DIR="${DEVBASE_CUSTOM_DIR:-}"      # Custom config directory path
DEBUG="${DEBUG:-}"                                # Debug mode (set DEBUG=1 for verbose output)
DEVBASE_THEME="${DEVBASE_THEME:-everforest-dark}" # Theme choice (default: everforest-dark)
DEVBASE_FONT="${DEVBASE_FONT:-monaspace}"         # Font choice (default: monaspace)
EDITOR="${EDITOR:-nvim}"                          # Default editor: nvim or nano
GIT_EMAIL="${GIT_EMAIL:-$USER@$(hostname)}"       # Git email for non-interactive (default: user@hostname)
GIT_NAME="${GIT_NAME:-DevBase User}"              # Git name for non-interactive (default: DevBase User)
MISE_GITHUB_TOKEN="${MISE_GITHUB_TOKEN:-}"        # GitHub token for mise downloads
SSH_KEY_PASSPHRASE="${SSH_KEY_PASSPHRASE:-}"      # SSH key passphrase

# XDG directories (may be pre-set by user, defaults follow XDG Base Directory spec)
XDG_BIN_HOME="${XDG_BIN_HOME:-${HOME}/.local/bin}" # Not in spec, but follows pattern
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"

# Network configuration (may be set by org.env file when sourced)
DEVBASE_PROXY_URL="${DEVBASE_PROXY_URL:-}"
DEVBASE_NO_PROXY_DOMAINS="${DEVBASE_NO_PROXY_DOMAINS:-}"
DEVBASE_REGISTRY_URL="${DEVBASE_REGISTRY_URL:-}"
DEVBASE_EMAIL_DOMAIN="${DEVBASE_EMAIL_DOMAIN:-}"
DEVBASE_LOCALE="${DEVBASE_LOCALE:-}"
DEVBASE_CONTAINERS_REGISTRY="${DEVBASE_CONTAINERS_REGISTRY:-}"
DEVBASE_PROXY_HOST="${DEVBASE_PROXY_HOST:-}"
DEVBASE_PROXY_PORT="${DEVBASE_PROXY_PORT:-}"

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
DEVBASE_VSCODE_NEOVIM="${DEVBASE_VSCODE_NEOVIM:-}"         # Install VSCode Neovim extension

# SSH key management configuration
DEVBASE_SSH_KEY_ACTION="${DEVBASE_SSH_KEY_ACTION:-}"                             # SSH key action: new, keep, or import
DEVBASE_SSH_KEY_PATH="${DEVBASE_SSH_KEY_PATH:-~/.ssh/id_ecdsa_nistp521_devbase}" # SSH key path
DEVBASE_SSH_ALLOW_EMPTY_PW="${DEVBASE_SSH_ALLOW_EMPTY_PW:-false}"                # Allow empty SSH key passphrase
GENERATED_SSH_PASSPHRASE="${GENERATED_SSH_PASSPHRASE:-false}"                    # Flag: passphrase was auto-generated

# Environment and Git configuration
DEVBASE_GIT_DEFAULT_BRANCH="${DEVBASE_GIT_DEFAULT_BRANCH:-main}" # Default Git branch name
DEVBASE_ENV_NAME="${DEVBASE_ENV_NAME:-default}"                  # Environment name

# Advanced configuration (offline installs, registry overrides)
DEVBASE_DEB_CACHE="${DEVBASE_DEB_CACHE:-}"                   # Path to offline .deb package cache
JMC_DOWNLOAD="${JMC_DOWNLOAD:-}"                             # JMC download URL override
DEVBASE_NO_PROXY_JAVA="${DEVBASE_NO_PROXY_JAVA:-}"           # Java-specific no-proxy domains
DEVBASE_REGISTRY_CONTAINER="${DEVBASE_REGISTRY_CONTAINER:-}" # Container registry override

# Non-interactive mode flag (initialized here, may be set by --non-interactive arg)
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

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
#   DEVBASE_ENV, DEVBASE_ENV_FILE, DEVBASE_PROXY_URL, DEVBASE_NO_PROXY_DOMAINS,
#   DEVBASE_REGISTRY_URL, DEVBASE_CONTAINERS_REGISTRY, DEVBASE_EMAIL_DOMAIN
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
    --help | -h)
      printf "Usage: %s [OPTIONS]\n" "$0"
      printf "\n"
      printf "Options:\n"
      printf "  --non-interactive  Run in non-interactive mode (for CI/automation)\n"
      printf "  --help, -h         Show this help message\n"
      exit 0
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
  source "${DEVBASE_LIBS}/define-colors.sh"
  source "${DEVBASE_LIBS}/utils.sh"
  source "${DEVBASE_LIBS}/ui-helpers.sh"
  source "${DEVBASE_LIBS}/validation.sh"
  source "${DEVBASE_LIBS}/handle-network.sh"
  source "${DEVBASE_LIBS}/process-templates.sh"
  source "${DEVBASE_LIBS}/check-requirements.sh"
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

show_welcome_banner() {
  local git_tag
  local git_sha
  local devbase_version

  git_tag=$(git -C "${DEVBASE_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")
  git_sha=$(git -C "${DEVBASE_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  if [[ -n "$git_tag" ]]; then
    devbase_version="$git_tag"
  else
    devbase_version="0.0.0-dev"
  fi

  print_box_top "DevBase Core Installation" 45 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_line "Started: $(date +"%H:%M:%S")" 45 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_line "Version: $devbase_version" 45 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_line "Commit:  $git_sha" 45 "${DEVBASE_COLORS[BOLD_CYAN]}"
  print_box_bottom 45 "${DEVBASE_COLORS[BOLD_CYAN]}"

  printf "\n"
  print_section "Configuration and Verification" "${DEVBASE_COLORS[BOLD_BLUE]}"
  printf "\n"
}

show_os_info() {
  display_os_info
}

show_repository_info() {
  printf "  • Running from: %s\n" "$DEVBASE_ROOT"
}

validate_custom_directory() {
  local dir="$1"

  local required_dirs=("config")

  for subdir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir/$subdir" ]]; then
      show_progress warning "Custom directory missing required folder: $subdir"
      return 1
    fi
  done

  if [[ ! -f "$dir/config/org.env" ]]; then
    show_progress warning "Custom directory missing required file: config/org.env"
    return 1
  fi

  return 0
}

find_custom_directory() {
  local candidates=(
    "${DEVBASE_CUSTOM_DIR}" # Imported at top - empty if user didn't set it
    "$DEVBASE_ROOT/../devbase-custom-config"
    "$DEVBASE_ROOT/devbase-custom-config"
  )

  for path in "${candidates[@]}"; do
    [[ -d "$path" ]] || continue

    local fullpath
    fullpath=$(cd "$path" && pwd) || continue

    if ! validate_custom_directory "$fullpath"; then
      show_progress error "Invalid custom directory structure: $fullpath"
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

    # Debug output if DEBUG is set (see docs/environment.adoc)
    if [[ "${DEBUG}" == "1" ]]; then
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
}

load_environment_configuration() {
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
  #   DEVBASE_PROXY_URL, DEVBASE_NO_PROXY_DOMAINS, DEVBASE_REGISTRY_URL, etc.
  # shellcheck disable=SC1090 # Dynamic source path
  source "${_DEVBASE_ENV_FILE}"

  # Export registry URL immediately after loading environment
  # This ensures it's available for connectivity checks
  if [[ -n "${DEVBASE_REGISTRY_URL}" ]]; then
    export DEVBASE_REGISTRY_URL
  fi
}

# Brief: Configure proxy environment variables for network operations
# Params: None
# Uses: DEVBASE_PROXY_URL, DEVBASE_NO_PROXY_DOMAINS (globals, optional)
# Modifies: http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY, no_proxy, NO_PROXY
#           (all exported)
# Returns: 0 always
# Side-effects: Sets proxy for all subsequent network operations
configure_proxy_settings() {
  if [[ -n "${DEVBASE_PROXY_URL}" ]]; then
    local proxy_url="${DEVBASE_PROXY_URL}"

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
  fi
}

# Mask credentials in proxy URLs: http://user:pass@host -> http://***:***@host
mask_url_credentials() {
  sed 's|://[^:]*:[^@]*@|://***:***@|'
}

# Brief: Check if required configuration variables are set
# Params: None
# Uses: DEVBASE_PROXY_URL, DEVBASE_REGISTRY_URL, _DEVBASE_ENV_FILE (globals)
# Returns: 0 always (warnings only, non-fatal)
# Side-effects: Displays warnings if variables are missing
check_required_config_variables() {
  local required_vars=()
  local missing_vars=()

  [[ -n "${DEVBASE_PROXY_URL}" ]] && required_vars+=("DEVBASE_PROXY_URL")
  [[ -n "${DEVBASE_REGISTRY_URL}" ]] && required_vars+=("DEVBASE_REGISTRY_URL")

  for var in "${required_vars[@]}"; do
    [[ -z "${!var:-}" ]] && missing_vars+=("$var")
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    show_progress warning "Missing custom configuration variables: ${missing_vars[*]}"
    show_progress info "These should be defined in: ${_DEVBASE_ENV_FILE}"
  fi
}

# Brief: Display network configuration (proxy, registry, no-proxy)
# Params: None
# Uses: DEVBASE_PROXY_URL, DEVBASE_REGISTRY_URL, DEVBASE_NO_PROXY_DOMAINS (globals)
# Returns: 0 always
# Side-effects: Displays info messages
display_network_configuration() {
  if [[ -n "${DEVBASE_PROXY_URL}" ]]; then
    local masked_proxy=$(echo "${DEVBASE_PROXY_URL}" | mask_url_credentials)
    show_progress info "Proxy URL: ${masked_proxy}"
  fi

  [[ -n "${DEVBASE_REGISTRY_URL}" ]] &&
    show_progress info "Registry URL: ${DEVBASE_REGISTRY_URL}"

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

  if [[ -n "$ssh_proxied_hosts" ]] && [[ -n "${DEVBASE_PROXY_HOST}" ]] && [[ -n "${DEVBASE_PROXY_PORT}" ]]; then
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
  printf "\n"
  show_progress step "Testing network connectivity"

  if ! check_network_connectivity; then
    show_progress warning "Network connectivity check failed - continuing anyway"
    show_progress info "Installation may fail if network access is required"
  fi
}

set_default_values() {
  # Export variables that were initialized in IMPORT section with defaults
  export DEVBASE_PROXY_URL DEVBASE_NO_PROXY_DOMAINS DEVBASE_REGISTRY_URL
  export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_BIN_HOME
  export DEVBASE_THEME DEVBASE_FONT

  # Define DevBase directories using XDG variables
  export DEVBASE_CACHE_DIR="${XDG_CACHE_HOME}/devbase"
  export DEVBASE_CONFIG_DIR="${XDG_CONFIG_HOME}/devbase"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"

  # Debug output if DEBUG environment variable is set
  if [[ "${DEBUG}" == "1" ]]; then
    show_progress info "Debug mode enabled"
    show_progress info "DEVBASE_ROOT=${DEVBASE_ROOT}"
    # shellcheck disable=SC2153 # _DEVBASE_FROM_GIT set in this function before this point
    show_progress info "_DEVBASE_FROM_GIT=${_DEVBASE_FROM_GIT}"
    show_progress info "_DEVBASE_ENV_FILE=${_DEVBASE_ENV_FILE}"
    # shellcheck disable=SC2153 # _DEVBASE_ENV set by detect_environment() before this function is called
    show_progress info "_DEVBASE_ENV=${_DEVBASE_ENV}"
    [[ -n "${DEVBASE_PROXY_URL}" ]] && show_progress info "Proxy configured: ${DEVBASE_PROXY_URL}"
  fi
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
  initialize_devbase_paths
  load_devbase_libraries

  show_welcome_banner
  show_os_info
  check_required_tools
  show_repository_info
  detect_environment

  find_custom_directory
  load_environment_configuration
  configure_proxy_settings
  test_generic_network_connectivity
  validate_custom_config
  run_pre_install_hook
  set_default_values

  run_installation
}

main "$@"
