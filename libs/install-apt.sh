#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

if [[ -z "${DEVBASE_DOT:-}" ]]; then
  echo "ERROR: DEVBASE_DOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Read APT package list from configuration file
# Params: None
# Uses: DEVBASE_DOT, _DEVBASE_CUSTOM_PACKAGES (globals)
# Returns: 0 on success, 1 if file not found or unreadable
# Outputs: Array of package names to global APT_PACKAGES_ALL
# Side-effects: Populates APT_PACKAGES_ALL array, filters WSL-specific packages
load_apt_packages() {
  local pkg_file="${DEVBASE_DOT}/.config/devbase/apt-packages.txt"

  # Check for custom package list override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/apt-packages.txt" ]]; then
    pkg_file="${_DEVBASE_CUSTOM_PACKAGES}/apt-packages.txt"
    show_progress info "Using custom APT package list: $pkg_file"
  fi

  if [[ ! -f "$pkg_file" ]]; then
    show_progress error "APT package list not found: $pkg_file"
    return 1
  fi

  if [[ ! -r "$pkg_file" ]]; then
    show_progress error "APT package list not readable: $pkg_file"
    return 1
  fi

  # Read packages from file, parse inline tags
  local packages=()

  while IFS= read -r line; do
    # Skip pure comment lines (starting with #)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Skip empty lines
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Extract package name (everything before #) and trim whitespace
    local pkg
    pkg=$(printf '%s' "${line%%#*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    [[ -z "$pkg" ]] && continue

    # Extract tags from inline comment (everything after #)
    local tags=""
    if [[ "$line" =~ \#[[:space:]]*(.*) ]]; then
      tags="${BASH_REMATCH[1]}"
    fi

    # Check for @skip-wsl tag (uses existing is_wsl function)
    if [[ "$tags" =~ @skip-wsl ]] && is_wsl; then
      continue
    fi

    packages+=("$pkg")
  done <"$pkg_file"

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress error "No valid packages found in $pkg_file"
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
  retry_command sudo apt-get -q update 2>&1 | sed 's/^/    /'
  return "${PIPESTATUS[0]}"
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

  retry_command sudo apt-get -y -q install "${packages[@]}" 2>&1 | sed 's/^/    /'
  return "${PIPESTATUS[0]}"
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
  if sudo apt-get install -y -q fonts-liberation fonts-liberation-sans-narrow fonts-dejavu fonts-dejavu-extra 2>&1 | sed 's/^/    /'; then
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
    return "${PIPESTATUS[0]}"
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
  echo

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

  echo
  show_progress success "$msg"

  return 0
}
