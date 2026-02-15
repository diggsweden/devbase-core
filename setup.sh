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
  source "${DEVBASE_LIBS}/bootstrap-ui.sh"
  source "${DEVBASE_LIBS}/bootstrap-config.sh"
  source "${DEVBASE_LIBS}/bootstrap.sh"
  source "${DEVBASE_LIBS}/migrations.sh"
  source "${DEVBASE_LIBS}/persist.sh"
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

  local packages="${DEVBASE_SELECTED_PACKS:-${DEVBASE_DEFAULT_PACKS:-}}"
  if [[ -n "$packages" ]]; then
    show_progress info "  - $(ui_message dry_run_plan_packages): $packages"
  fi
}

run_installation() {
  # Run the main installation script
  _INSTALL_SCRIPT="${DEVBASE_LIBS}/install.sh"

  if [[ -f "$_INSTALL_SCRIPT" ]]; then
    # Only export what child processes actually need
    # Proxy variables already exported above if configured
    # shellcheck disable=SC2153 # _DEVBASE_ENV/_DEVBASE_ENV_FILE set during bootstrap
    export DEVBASE_ENV="$_DEVBASE_ENV" # Environment type (ubuntu/wsl-ubuntu)
    # shellcheck disable=SC2153 # _DEVBASE_ENV_FILE set during bootstrap
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
