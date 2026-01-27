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
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum spin --spinner dot --title "Updating package lists..." -- \
      sudo dnf check-update --quiet || true # dnf check-update returns 100 if updates available
    return 0
  fi

  # Whiptail mode (default)
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

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum spin --spinner dot --title "Installing ${pkg_count} packages..." -- \
      sudo dnf install -y --quiet "${packages[@]}"
    return $?
  fi

  # Whiptail mode (default)
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

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    if gum spin --spinner dot --title "Installing Liberation & DejaVu fonts..." -- \
      sudo dnf install -y --quiet "${font_packages[@]}"; then
      command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
      return 0
    fi
    return 1
  fi

  # Whiptail mode (default)
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

# Brief: Configure Firefox to use OpenSC PKCS#11 module for smart card support
# Params: None
# Uses: HOME, show_progress (globals/functions)
# Returns: 0 on success
# Side-effects: Adds OpenSC module to Firefox pkcs11.txt
_pkg_dnf_configure_firefox_opensc() {
  # OpenSC library path on Fedora
  local opensc_lib="/usr/lib64/opensc-pkcs11.so"

  # Skip if OpenSC library not installed
  if [[ ! -f "$opensc_lib" ]]; then
    show_progress info "OpenSC PKCS#11 library not found, skipping Firefox smart card configuration"
    return 0
  fi

  # Find Firefox profile directory
  local profile_dir
  profile_dir=$(find "${HOME}/.mozilla/firefox" -maxdepth 1 -type d -name '*.default*' 2>/dev/null | head -1)

  if [[ -z "$profile_dir" ]]; then
    show_progress info "No Firefox profile found, skipping OpenSC configuration"
    return 0
  fi

  local pkcs11_file="${profile_dir}/pkcs11.txt"

  # Skip if OpenSC already configured
  if [[ -f "$pkcs11_file" ]] && grep -q "opensc-pkcs11.so" "$pkcs11_file" 2>/dev/null; then
    show_progress info "OpenSC already configured in Firefox"
    return 0
  fi

  # Add OpenSC module to pkcs11.txt
  printf '%s\n' "library=${opensc_lib}" "name=OpenSC" >>"$pkcs11_file"

  show_progress success "Firefox configured for smart card support (OpenSC)"
  return 0
}
