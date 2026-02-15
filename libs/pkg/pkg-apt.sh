#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# APT package manager implementation for Debian/Ubuntu
# This file is sourced by pkg-manager.sh - do not source directly

# =============================================================================
# CORE PACKAGE OPERATIONS
# =============================================================================

# Brief: Update APT package cache
# Params: None
# Returns: 0 on success, non-zero on failure
# Side-effects: Updates APT cache
_pkg_apt_update() {
  run_with_spinner "Updating package lists" sudo apt-get -qq update
}

# Brief: Install APT packages with real-time progress (whiptail only)
# Params: $@ - package names
# Returns: apt exit code
# Parses "Unpacking" and "Setting up" lines to update gauge with real progress
_pkg_apt_install_with_progress() {
  local packages=("$@")
  local total=${#packages[@]}
  local unpack_count=0
  local setup_count=0
  local current_pkg=""
  local exit_code=0
  local last_line=""

  _wt_update_gauge "Preparing to install $total packages..." 0

  # Use process substitution to keep variables in main shell
  # Remove -qq to get progress output, use -q for less noise
  while IFS= read -r line; do
    last_line="$line"
    # Parse "Unpacking package-name (version) ..."
    if [[ "$line" =~ ^Unpacking[[:space:]]+([^[:space:]]+) ]]; then
      current_pkg="${BASH_REMATCH[1]}"
      # Remove :amd64 or similar arch suffix
      current_pkg="${current_pkg%%:*}"
      unpack_count=$((unpack_count + 1))
      # Unpacking is 0-50% of progress
      local percent=$(((unpack_count * 50) / total))
      _wt_update_gauge "Unpacking: $current_pkg ($unpack_count/$total)" "$percent"
    # Parse "Setting up package-name (version) ..."
    elif [[ "$line" =~ ^Setting[[:space:]]+up[[:space:]]+([^[:space:]]+) ]]; then
      current_pkg="${BASH_REMATCH[1]}"
      current_pkg="${current_pkg%%:*}"
      setup_count=$((setup_count + 1))
      # Setting up is 50-100% of progress
      local percent=$((50 + (setup_count * 50) / total))
      _wt_update_gauge "Configuring: $current_pkg ($setup_count/$total)" "$percent"
    fi
  done < <(
    sudo apt-get install -y -q "${packages[@]}" 2>&1
    echo "APT_EXIT_CODE:$?"
  )

  # Extract exit code from last line
  if [[ "$last_line" =~ APT_EXIT_CODE:([0-9]+) ]]; then
    exit_code="${BASH_REMATCH[1]}"
  fi

  # Check if parsing worked - if not, log warning
  if [[ $unpack_count -eq 0 ]] && [[ $setup_count -eq 0 ]] && [[ $total -gt 0 ]]; then
    show_progress warning "Could not parse apt progress output"
  fi

  if [[ $exit_code -eq 0 ]]; then
    _wt_update_gauge "Installed $total packages" 100
  fi

  return "$exit_code"
}

# Brief: Install APT packages
# Params: $@ - package names
# Returns: 0 on success, non-zero on failure
# Side-effects: Installs packages
_pkg_apt_install() {
  local packages=("$@")
  local pkg_count=${#packages[@]}

  [[ $pkg_count -eq 0 ]] && return 0

  # Whiptail mode with persistent gauge - use real progress tracking
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && _wt_gauge_is_running; then
    _pkg_apt_install_with_progress "${packages[@]}"
    return $?
  fi

  # All other modes - use run_with_spinner which handles gum/fallback and shows errors
  run_with_spinner "Installing ${pkg_count} packages" sudo apt-get -y -q install "${packages[@]}"
  return $?
}

# Brief: Remove unused APT packages
# Params: None
# Returns: 0 always
# Side-effects: Removes unused packages
_pkg_apt_cleanup() {
  sudo apt-get -qq autoremove -y
  return 0
}

# =============================================================================
# REPOSITORY MANAGEMENT
# =============================================================================

# Brief: Add a repository to APT sources
# Params: $1 - repo type (ppa), $2 - repo identifier
# Returns: 0 on success, 1 on failure
_pkg_apt_add_repo() {
  local repo_type="$1"
  local repo_id="$2"

  case "$repo_type" in
  ppa)
    # Use -n flag to skip automatic apt update
    if ! sudo add-apt-repository -y -n "ppa:$repo_id" &>/dev/null; then
      show_progress warning "Failed to add PPA: $repo_id"
      return 1
    fi
    ;;
  *)
    show_progress warning "Unknown APT repo type: $repo_type"
    return 1
    ;;
  esac

  return 0
}

# Brief: Add Fish shell PPA for version 4.x
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Adds fish-shell/release-4 PPA
_pkg_apt_add_fish_ppa() {
  show_progress info "Adding Fish shell 4.x PPA..."

  if ! _pkg_apt_add_repo "ppa" "fish-shell/release-4"; then
    show_progress warning "Failed to add Fish 4.x PPA (will use default version from Ubuntu repos)"
    return 1
  fi

  show_progress success "Fish 4.x PPA added"
  return 0
}

# =============================================================================
# LOCALE CONFIGURATION
# =============================================================================

# Brief: Configure system locale for Debian/Ubuntu
# Params: None
# Uses: DEVBASE_LOCALE (global)
# Returns: 0 always
# Side-effects: Generates and sets system locale
_pkg_apt_configure_locale() {
  [[ -z "${DEVBASE_LOCALE:-}" ]] && return 0

  local locale_name="${DEVBASE_LOCALE%.*}"
  if ! locale -a 2>/dev/null | grep -q "^${locale_name}"; then
    sudo locale-gen "${DEVBASE_LOCALE}"
    sudo update-locale LANG="${DEVBASE_LOCALE}"
  fi

  return 0
}

# =============================================================================
# FONT INSTALLATION
# =============================================================================

# Brief: Install Liberation and DejaVu fonts for APT
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Installs fonts, rebuilds font cache
_pkg_apt_install_fonts() {
  local font_packages=(
    fonts-liberation
    fonts-liberation-sans-narrow
    fonts-dejavu
    fonts-dejavu-extra
  )

  if run_with_spinner "Installing Liberation & DejaVu fonts" \
    sudo apt-get install -y -q "${font_packages[@]}"; then
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
    return 0
  fi
  return 1
}

# =============================================================================
# FIREFOX INSTALLATION (DEB FROM MOZILLA)
# =============================================================================

# Brief: Install Firefox from Mozilla's official APT repository (not snap)
# Params: None
# Uses: show_progress (function)
# Returns: 0 on success, 1 on failure
# Side-effects: Adds Mozilla APT repo, sets package priority, installs Firefox .deb
# Note: Firefox .deb is required for smart card/PKCS#11 support (snap has AppArmor restrictions)
_pkg_apt_install_firefox_deb() {
  show_progress info "Installing Firefox from Mozilla APT repository..."

  # Skip if already installed from Mozilla repo
  if command -v firefox &>/dev/null; then
    local firefox_source
    firefox_source=$(apt-cache policy firefox 2>/dev/null | grep -A1 '^\*\*\*' | tail -1 || echo "")
    if [[ "$firefox_source" == *"packages.mozilla.org"* ]]; then
      show_progress info "Firefox already installed from Mozilla repository"
      return 0
    fi
  fi

  # Remove snap version if present
  if snap list firefox &>/dev/null 2>&1; then
    show_progress info "Removing Firefox snap..."
    tui_run_cmd "Removing Firefox snap" sudo snap remove firefox
  fi

  # Remove Ubuntu's transitional firefox package if present
  if dpkg -l firefox 2>/dev/null | grep -q "^ii.*1:1snap"; then
    show_progress info "Removing Ubuntu transitional firefox package..."
    tui_run_cmd "Removing transitional package" sudo dpkg -r firefox
  fi

  # Create keyrings directory
  sudo install -d -m 0755 /etc/apt/keyrings

  # Download and install Mozilla's GPG key
  local mozilla_key="${_DEVBASE_TEMP:-/tmp}/mozilla-repo-signing-key.gpg"
  mkdir -p "$(dirname "$mozilla_key")"
  if ! download_file "${DEVBASE_URL_MOZILLA_GPG_KEY}" "$mozilla_key"; then
    show_progress error "Failed to download Mozilla GPG key"
    return 1
  fi
  if ! sudo install -m 0644 "$mozilla_key" /etc/apt/keyrings/packages.mozilla.org.asc; then
    show_progress error "Failed to install Mozilla GPG key"
    return 1
  fi

  # Add Mozilla APT repository
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] ${DEVBASE_URL_MOZILLA_APT_REPO} mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null

  # Set package priority to prefer Mozilla's Firefox and block Ubuntu's snap transitional package
  cat <<'EOF' | sudo tee /etc/apt/preferences.d/mozilla >/dev/null
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1001

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF

  # Update and install
  if ! run_with_spinner "Updating Mozilla repository" sudo apt-get -qq update; then
    show_progress error "Failed to update package cache after adding Mozilla repo"
    return 1
  fi

  if ! run_with_spinner "Installing Firefox" sudo apt-get -y -qq install firefox; then
    show_progress error "Failed to install Firefox from Mozilla repository"
    return 1
  fi

  show_progress success "Firefox installed from Mozilla APT repository"

  # Configure OpenSC for smart card support
  _pkg_apt_configure_firefox_opensc

  return 0
}

# Brief: Configure Firefox OpenSC for Debian/Ubuntu
# Side-effects: Delegates to shared _configure_firefox_opensc with multiarch path
_pkg_apt_configure_firefox_opensc() {
  local arch
  arch=$(dpkg --print-architecture 2>/dev/null || echo "x86_64")
  local multiarch
  case "$arch" in
  amd64) multiarch="x86_64-linux-gnu" ;;
  arm64) multiarch="aarch64-linux-gnu" ;;
  armhf) multiarch="arm-linux-gnueabihf" ;;
  i386) multiarch="i386-linux-gnu" ;;
  *) multiarch="x86_64-linux-gnu" ;;
  esac
  _configure_firefox_opensc "/usr/lib/${multiarch}/opensc-pkcs11.so"
}
