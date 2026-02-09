#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Package manager abstraction layer
# Provides unified pkg_* functions that delegate to distro-specific implementations
#
# Usage:
#   source libs/pkg/pkg-manager.sh
#   pkg_update
#   pkg_install curl git vim
#   pkg_cleanup

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Source distro detection if not already loaded
if ! declare -f get_distro &>/dev/null; then
  # shellcheck source=../distro.sh
  source "${DEVBASE_ROOT}/libs/distro.sh"
fi

# Detect and cache the package manager
_PKG_MANAGER="${_PKG_MANAGER:-$(get_pkg_manager)}"

# =============================================================================
# PACKAGE LOADING
# =============================================================================

# Brief: Load package list from packages.yaml for current distro
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_SELECTED_PACKS, get_system_packages (globals/functions)
# Returns: 0 on success, 1 if no packages found
# Outputs: Array of package names to global SYSTEM_PACKAGES_ALL
# Side-effects: Populates SYSTEM_PACKAGES_ALL array, filters by tags
load_system_packages() {
  # Set up for parse-packages.sh
  # shellcheck disable=SC2153 # DEVBASE_DOT is set in setup.sh, not a misspelling of DEVBASE_ROOT
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="${DEVBASE_SELECTED_PACKS:-java node python go ruby}"

  # Check for custom packages override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" ]]; then
    export PACKAGES_CUSTOM_YAML="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
    show_progress info "Using custom package overrides"
  fi

  if [[ ! -f "$PACKAGES_YAML" ]]; then
    show_progress error "Package configuration not found: $PACKAGES_YAML"
    return 1
  fi

  # Source parser if not already loaded
  if ! declare -f get_system_packages &>/dev/null; then
    # shellcheck source=../parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  # Get packages from parser (common + distro-specific)
  local packages=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && packages+=("$pkg")
  done < <(get_system_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress error "No system packages found in configuration"
    return 1
  fi

  # Export as readonly array
  readonly SYSTEM_PACKAGES_ALL=("${packages[@]}")

  return 0
}

# =============================================================================
# PACKAGE MANAGER INTERFACE
# =============================================================================

# Brief: Update package manager cache
# Params: None
# Returns: 0 on success, non-zero on failure
# Side-effects: Updates package cache
pkg_update() {
  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_update
    ;;
  dnf)
    _pkg_dnf_update
    ;;
  *)
    show_progress error "Unsupported package manager: $_PKG_MANAGER"
    return 1
    ;;
  esac
}

# Brief: Install packages
# Params: $@ - package names
# Returns: 0 on success, non-zero on failure
# Side-effects: Installs packages
pkg_install() {
  local packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return 0

  for pkg in "${packages[@]}"; do
    validate_not_empty "$pkg" "Package name" || return 1
  done

  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_install "${packages[@]}"
    ;;
  dnf)
    _pkg_dnf_install "${packages[@]}"
    ;;
  *)
    show_progress error "Unsupported package manager: $_PKG_MANAGER"
    return 1
    ;;
  esac
}

# Brief: Remove unused packages
# Params: None
# Returns: 0 always
# Side-effects: Removes unused packages
pkg_cleanup() {
  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_cleanup
    ;;
  dnf)
    _pkg_dnf_cleanup
    ;;
  *)
    # Silently ignore unsupported managers for cleanup
    return 0
    ;;
  esac
}

# Brief: Add a third-party repository
# Params: $1 - repo type (ppa, copr, etc.), $2 - repo identifier
# Returns: 0 on success, non-zero on failure
# Side-effects: Adds repository to system
pkg_add_repo() {
  local repo_type="$1"
  local repo_id="$2"

  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_add_repo "$repo_type" "$repo_id"
    ;;
  dnf)
    _pkg_dnf_add_repo "$repo_type" "$repo_id"
    ;;
  *)
    show_progress warning "Repository adding not implemented for $_PKG_MANAGER"
    return 1
    ;;
  esac
}

# =============================================================================
# LOCALE CONFIGURATION
# =============================================================================

# Brief: Configure system locale if DEVBASE_LOCALE is set
# Params: None
# Uses: DEVBASE_LOCALE (global, optional)
# Returns: 0 always
# Side-effects: Generates and sets system locale
configure_locale() {
  [[ -z "${DEVBASE_LOCALE:-}" ]] && return 0

  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_configure_locale
    ;;
  dnf)
    _pkg_dnf_configure_locale
    ;;
  *)
    show_progress info "Locale configuration not implemented for $_PKG_MANAGER"
    ;;
  esac

  return 0
}

# =============================================================================
# FONT INSTALLATION
# =============================================================================

# Brief: Install Liberation and DejaVu fonts
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Installs fonts, rebuilds font cache
install_liberation_fonts() {
  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_install_fonts
    ;;
  dnf)
    _pkg_dnf_install_fonts
    ;;
  *)
    show_progress warning "Font installation not implemented for $_PKG_MANAGER"
    return 1
    ;;
  esac
}

# =============================================================================
# DISTRO-SPECIFIC FEATURES
# =============================================================================

# Brief: Add Fish shell repository for latest version
# Params: None
# Returns: 0 on success, 1 on failure
add_fish_repo() {
  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_add_fish_ppa
    ;;
  dnf)
    # Fedora has recent Fish in default repos
    show_progress info "Fish 4.x available in default repos"
    return 0
    ;;
  *)
    show_progress info "Fish repository not available for $_PKG_MANAGER"
    return 0
    ;;
  esac
}

# Brief: Install Firefox from official repository (not snap)
# Params: None
# Returns: 0 on success, 1 on failure
install_firefox_native() {
  case "$_PKG_MANAGER" in
  apt)
    _pkg_apt_install_firefox_deb
    ;;
  dnf)
    _pkg_dnf_install_firefox
    ;;
  *)
    show_progress warning "Firefox installation not implemented for $_PKG_MANAGER"
    return 1
    ;;
  esac
}

# =============================================================================
# MAIN INSTALLER
# =============================================================================

# Brief: Install all system packages, configure locale, and install fonts
# Params: None
# Uses: load_system_packages, SYSTEM_PACKAGES_ALL (functions/global array)
# Returns: 0 on success, 1 on failure
# Side-effects: Loads package list, installs packages, configures locale, cleans up
install_system_packages() {
  show_progress info "Installing system packages..."

  # Add distro-specific repos for latest versions
  add_fish_repo

  # Load package list from file
  if ! load_system_packages; then
    show_progress error "Failed to load system package list"
    return 1
  fi

  local total_packages=${#SYSTEM_PACKAGES_ALL[@]}
  show_progress info "Found $total_packages packages to install"
  tui_blank_line

  if ! pkg_update; then
    show_progress error "Failed to update package cache - check network/proxy settings"
    return 1
  fi

  if ! pkg_install "${SYSTEM_PACKAGES_ALL[@]}"; then
    show_progress warning "Some packages failed to install"
    return 1
  fi

  local locale_configured=""
  if configure_locale; then
    [[ -n "${DEVBASE_LOCALE:-}" ]] && locale_configured="${DEVBASE_LOCALE}"
  fi

  local fonts_installed=false
  if install_liberation_fonts; then
    fonts_installed=true
  fi

  local msg="System packages installed (${total_packages} packages"
  [[ -n "$locale_configured" ]] && msg="${msg}, locale: ${locale_configured}"
  [[ "$fonts_installed" == true ]] && msg="${msg}, Liberation+DejaVu fonts"
  msg="${msg})"

  tui_blank_line
  show_progress success "$msg"

  return 0
}

# =============================================================================
# LOAD DISTRO-SPECIFIC IMPLEMENTATION
# =============================================================================

case "$_PKG_MANAGER" in
apt)
  # shellcheck source=pkg-apt.sh
  source "${DEVBASE_ROOT}/libs/pkg/pkg-apt.sh"
  ;;
dnf)
  # shellcheck source=pkg-dnf.sh
  source "${DEVBASE_ROOT}/libs/pkg/pkg-dnf.sh"
  ;;
esac
