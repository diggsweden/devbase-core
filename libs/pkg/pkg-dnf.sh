#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# DNF package manager implementation for Fedora/RHEL
# This file is sourced by pkg-manager.sh - do not source directly

set -uo pipefail

# =============================================================================
# CORE PACKAGE OPERATIONS
# =============================================================================

# Brief: Update DNF package cache
# Params: None
# Returns: 0 on success, non-zero on failure
# Side-effects: Updates DNF cache
_pkg_dnf_update() {
  run_with_spinner "Updating package lists" sudo dnf check-update --quiet || true
  return 0
}

# Brief: Install DNF packages
# Params: $@ - package names
# Returns: 0 on success, non-zero on failure
# Side-effects: Installs packages
_pkg_dnf_install() {
  local packages=("$@")
  local pkg_count=${#packages[@]}

  [[ $pkg_count -eq 0 ]] && return 0

  run_with_spinner "Installing ${pkg_count} packages" sudo dnf install -y --quiet "${packages[@]}"
  return $?
}

# Brief: Remove unused DNF packages
# Params: None
# Returns: 0 always
# Side-effects: Removes unused packages
_pkg_dnf_cleanup() {
  sudo dnf autoremove -y --quiet
  return 0
}

# =============================================================================
# REPOSITORY MANAGEMENT
# =============================================================================

# Brief: Add a repository to DNF
# Params: $1 - repo type (copr, rpm), $2 - repo identifier
# Returns: 0 on success, 1 on failure
_pkg_dnf_add_repo() {
  local repo_type="$1"
  local repo_id="$2"

  case "$repo_type" in
  copr)
    if ! sudo dnf copr enable -y "$repo_id" &>/dev/null; then
      show_progress warning "Failed to enable COPR: $repo_id"
      return 1
    fi
    ;;
  rpm)
    if ! sudo dnf install -y "$repo_id" &>/dev/null; then
      show_progress warning "Failed to add RPM repo: $repo_id"
      return 1
    fi
    ;;
  *)
    show_progress warning "Unknown DNF repo type: $repo_type"
    return 1
    ;;
  esac

  return 0
}

# =============================================================================
# LOCALE CONFIGURATION
# =============================================================================

# Brief: Configure system locale for Fedora
# Params: None
# Uses: DEVBASE_LOCALE (global)
# Returns: 0 always
# Side-effects: Sets system locale
_pkg_dnf_configure_locale() {
  [[ -z "${DEVBASE_LOCALE:-}" ]] && return 0

  # Fedora uses localectl for locale settings
  if command -v localectl &>/dev/null; then
    sudo localectl set-locale LANG="${DEVBASE_LOCALE}" 2>/dev/null || true
  fi

  return 0
}

# =============================================================================
# FONT INSTALLATION
# =============================================================================

# Brief: Install Liberation and DejaVu fonts for DNF
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Installs fonts, rebuilds font cache
_pkg_dnf_install_fonts() {
  local font_packages=(
    liberation-fonts
    liberation-narrow-fonts
    dejavu-fonts-all
  )

  if run_with_spinner "Installing Liberation & DejaVu fonts" \
    sudo dnf install -y --quiet "${font_packages[@]}"; then
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
    return 0
  fi
  return 1
}

# =============================================================================
# FIREFOX (NATIVE RPM)
# =============================================================================

# Brief: Install Firefox from Fedora repos (native RPM, not Flatpak)
# Params: None
# Returns: 0 on success, 1 on failure
# Note: Fedora ships native Firefox RPM by default, no special handling needed
_pkg_dnf_install_firefox() {
  show_progress info "Installing Firefox..."

  if _pkg_dnf_install firefox; then
    show_progress success "Firefox installed"

    # Configure OpenSC for smart card support if available
    _pkg_dnf_configure_firefox_opensc
    return 0
  fi

  return 1
}

# Brief: Configure Firefox OpenSC for Fedora
# Side-effects: Delegates to shared _configure_firefox_opensc
_pkg_dnf_configure_firefox_opensc() {
  _configure_firefox_opensc "/usr/lib64/opensc-pkcs11.so"
}
