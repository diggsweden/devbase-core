#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

if [[ -z "${DEVBASE_DOT:-}" ]]; then
  echo "ERROR: DEVBASE_DOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Read APT package list from packages.yaml
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_SELECTED_PACKS, get_apt_packages (globals/functions)
# Returns: 0 on success, 1 if no packages found
# Outputs: Array of package names to global APT_PACKAGES_ALL
# Side-effects: Populates APT_PACKAGES_ALL array, filters by tags
load_apt_packages() {
  # Set up for parse-packages.sh
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
  if ! declare -f get_apt_packages &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  # Get packages from parser
  local packages=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && packages+=("$pkg")
  done < <(get_apt_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress error "No APT packages found in configuration"
    return 1
  fi

  # Export as readonly array
  readonly APT_PACKAGES_ALL=("${packages[@]}")

  return 0
}

# Brief: Update APT package cache
# Params: None
# Returns: 0 on success, non-zero on failure
# Side-effects: Updates APT cache
pkg_update() {
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum spin --spinner dot --show-error --title "Updating package lists..." -- \
      sudo apt-get -qq update
    return $?
  fi

  # Whiptail mode (default)
  run_with_spinner "Updating package lists" sudo apt-get -qq update
  return $?
}

# Brief: Install APT packages with retry logic
# Params: $@ - package names
# Returns: 0 on success, non-zero on failure
# Side-effects: Installs packages
pkg_install() {
  local packages=("$@")

  [[ ${#packages[@]} -eq 0 ]] && return 0

  for pkg in "${packages[@]}"; do
    validate_not_empty "$pkg" "Package name" || return 1
  done

  local pkg_count=${#packages[@]}

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum spin --spinner dot --show-error --title "Installing ${pkg_count} packages..." -- \
      sudo apt-get -y -qq install "${packages[@]}"
    return $?
  fi

  # Whiptail mode (default)
  run_with_spinner "Installing ${pkg_count} packages" sudo apt-get -y -qq install "${packages[@]}"
  return $?
}

# Brief: Remove unused APT packages
# Params: None
# Returns: 0 always
# Side-effects: Removes unused packages
pkg_cleanup() {
  sudo apt-get -qq autoremove -y
  return 0
}

# Brief: Configure system locale if DEVBASE_LOCALE is set
# Params: None
# Uses: DEVBASE_LOCALE (global, optional)
# Returns: 0 always
# Side-effects: Generates and sets system locale
configure_locale() {
  [[ -z "${DEVBASE_LOCALE:-}" ]] && return 0

  local locale_name="${DEVBASE_LOCALE%.*}"
  if ! locale -a 2>/dev/null | grep -q "^${locale_name}"; then
    sudo locale-gen "${DEVBASE_LOCALE}"
    sudo update-locale LANG="${DEVBASE_LOCALE}"
  fi

  return 0
}

# Brief: Install Liberation and DejaVu fonts (metric-compatible replacements for common fonts)
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Installs fonts, rebuilds font cache
install_liberation_fonts() {
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    if gum spin --spinner dot --show-error --title "Installing Liberation & DejaVu fonts..." -- \
      sudo apt-get install -y -qq fonts-liberation fonts-liberation-sans-narrow fonts-dejavu fonts-dejavu-extra; then
      command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
      return 0
    fi
    return 1
  fi

  # Whiptail mode (default)
  if run_with_spinner "Installing Liberation & DejaVu fonts" \
    sudo apt-get install -y -qq fonts-liberation fonts-liberation-sans-narrow fonts-dejavu fonts-dejavu-extra; then
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
    return 0
  fi
  return 1
}

# Brief: Add Fish shell PPA for version 4.x
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Adds fish-shell/release-4 PPA for Fish 4.x with GPG key, skips apt update
add_fish_ppa() {
  show_progress info "Adding Fish shell 4.x PPA..."

  # Use -n flag to skip automatic apt update (we'll do it later in pkg_update)
  # add-apt-repository with -n flag:
  # 1. Downloads and verifies GPG signing key via HTTPS
  # 2. Adds repository to /etc/apt/sources.list.d/
  # 3. Does NOT run apt update (we handle that separately)
  if ! sudo add-apt-repository -y -n ppa:fish-shell/release-4 &>/dev/null; then
    show_progress warning "Failed to add Fish 4.x PPA (will use default version from Ubuntu repos)"
    return 1
  fi

  show_progress success "Fish 4.x PPA added"
  return 0
}

# Brief: Install Firefox from Mozilla's official APT repository (not snap)
# Params: None
# Uses: show_progress (function)
# Returns: 0 on success, 1 on failure
# Side-effects: Adds Mozilla APT repo, sets package priority, installs Firefox .deb
# Note: Firefox .deb is required for smart card/PKCS#11 support (snap has AppArmor restrictions)
install_firefox_deb() {
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
  # This package redirects to snap and blocks installation from Mozilla repo
  if dpkg -l firefox 2>/dev/null | grep -q "^ii.*1:1snap"; then
    show_progress info "Removing Ubuntu transitional firefox package..."
    tui_run_cmd "Removing transitional package" sudo dpkg -r firefox
  fi

  # Create keyrings directory
  sudo install -d -m 0755 /etc/apt/keyrings

  # Download and install Mozilla's GPG key
  local mozilla_key="${_DEVBASE_TEMP:-/tmp}/mozilla-repo-signing-key.gpg"
  mkdir -p "$(dirname "$mozilla_key")"
  if ! download_file "https://packages.mozilla.org/apt/repo-signing-key.gpg" "$mozilla_key"; then
    show_progress error "Failed to download Mozilla GPG key"
    return 1
  fi
  if ! sudo install -m 0644 "$mozilla_key" /etc/apt/keyrings/packages.mozilla.org.asc; then
    show_progress error "Failed to install Mozilla GPG key"
    return 1
  fi

  # Add Mozilla APT repository
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null

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
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    if ! gum spin --spinner dot --show-error --title "Updating Mozilla repository..." -- \
      sudo apt-get -qq update; then
      show_progress error "Failed to update package cache after adding Mozilla repo"
      return 1
    fi

    if ! gum spin --spinner dot --show-error --title "Installing Firefox..." -- \
      sudo apt-get -y -qq install firefox; then
      show_progress error "Failed to install Firefox from Mozilla repository"
      return 1
    fi
  else
    # Whiptail mode (default)
    if ! run_with_spinner "Updating Mozilla repository" sudo apt-get -qq update; then
      show_progress error "Failed to update package cache after adding Mozilla repo"
      return 1
    fi

    if ! run_with_spinner "Installing Firefox" sudo apt-get -y -qq install firefox; then
      show_progress error "Failed to install Firefox from Mozilla repository"
      return 1
    fi
  fi

  show_progress success "Firefox installed from Mozilla APT repository"

  # Configure OpenSC for smart card support
  configure_firefox_opensc

  return 0
}

# Brief: Configure Firefox to use OpenSC PKCS#11 module for smart card support
# Params: None
# Uses: HOME, show_progress (globals/functions)
# Returns: 0 on success, 1 if no Firefox profile found
# Side-effects: Adds OpenSC module to Firefox pkcs11.txt
# Note: Requires opensc-pkcs11 package to be installed (defined in packages.yaml)
configure_firefox_opensc() {
  local opensc_lib="/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

  # Skip if OpenSC library not installed
  if [[ ! -f "$opensc_lib" ]]; then
    show_progress info "OpenSC PKCS#11 library not found, skipping Firefox smart card configuration"
    return 0
  fi

  # Find Firefox profile directory
  local profile_dir
  profile_dir=$(find "${HOME}/.mozilla/firefox" -maxdepth 1 -type d -name '*.default*' 2>/dev/null | head -1)

  if [[ -z "$profile_dir" ]]; then
    show_progress info "No Firefox profile found, skipping OpenSC configuration (will be configured on first Firefox launch)"
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

# Brief: Install all APT packages, configure locale, and install fonts
# Params: None
# Uses: load_apt_packages, APT_PACKAGES_ALL (functions/global array)
# Returns: 0 on success, 1 on failure
# Side-effects: Loads package list, installs packages, configures locale, cleans up
install_apt_packages() {
  show_progress info "Installing system packages..."

  # Add Fish PPA before updating package cache
  add_fish_ppa

  # Load package list from file
  if ! load_apt_packages; then
    show_progress error "Failed to load APT package list"
    return 1
  fi

  local total_packages=${#APT_PACKAGES_ALL[@]}
  show_progress info "Found $total_packages packages to install"
  tui_blank_line

  if ! pkg_update; then
    show_progress error "Failed to update package cache - check network/proxy settings"
    return 1
  fi

  if ! pkg_install "${APT_PACKAGES_ALL[@]}"; then
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
