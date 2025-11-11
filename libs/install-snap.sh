#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

if [[ -z "${DEVBASE_DOT:-}" ]]; then
  echo "ERROR: DEVBASE_DOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Read snap package list from configuration file
# Params: None
# Uses: DEVBASE_DOT, _DEVBASE_CUSTOM_PACKAGES (globals)
# Returns: 0 on success, 1 if file not found or unreadable
# Outputs: Arrays of package names and options to global SNAP_PACKAGES and SNAP_OPTIONS
# Side-effects: Populates SNAP_PACKAGES and SNAP_OPTIONS arrays
load_snap_packages() {
  local pkg_file="${DEVBASE_DOT}/.config/devbase/snap-packages.txt"

  # Check for custom package list override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/snap-packages.txt" ]]; then
    pkg_file="${_DEVBASE_CUSTOM_PACKAGES}/snap-packages.txt"
    show_progress info "Using custom snap package list: $pkg_file"
  fi

  if [[ ! -f "$pkg_file" ]]; then
    show_progress error "Snap package list not found: $pkg_file"
    return 1
  fi

  if [[ ! -r "$pkg_file" ]]; then
    show_progress error "Snap package list not readable: $pkg_file"
    return 1
  fi

  # Read packages from file
  local packages=()
  local options=()

  while IFS= read -r line; do
    # Skip pure comment lines (starting with #)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Skip empty lines
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Extract package name and options
    # Format: package_name [options]
    local pkg_name
    local pkg_options=""

    # Read first word as package name, rest as options
    read -r pkg_name pkg_options <<<"$line"

    [[ -z "$pkg_name" ]] && continue

    packages+=("$pkg_name")
    options+=("$pkg_options")
  done <"$pkg_file"

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress error "No valid snap packages found in $pkg_file"
    return 1
  fi

  # Export as readonly arrays
  readonly SNAP_PACKAGES=("${packages[@]}")
  readonly SNAP_OPTIONS=("${options[@]}")

  return 0
}

# Brief: Configure snap package manager proxy settings
# Params: None
# Uses: DEVBASE_PROXY_URL (global, optional)
# Returns: 0 always
# Side-effects: Sets snap system proxy configuration
configure_snap_proxy() {
  [[ -z "${DEVBASE_PROXY_URL}" ]] && return 0
  command -v snap &>/dev/null || return 0

  sudo snap unset system proxy.http 2>/dev/null || true
  sudo snap unset system proxy.https 2>/dev/null || true
  sudo snap set system proxy.http="${DEVBASE_PROXY_URL}" || show_progress warning "Failed to set snap http proxy"
  sudo snap set system proxy.https="${DEVBASE_PROXY_URL}" || show_progress warning "Failed to set snap https proxy"

  return 0
}

# Brief: Install snap package with retry and auto-refresh handling
# Params: $1 - snap_name, $2 - snap_options (optional)
# Uses: show_progress (from ui-helpers)
# Returns: 0 on success or if already installed, 1 if install fails
# Side-effects: Waits for auto-refresh, installs snap package
snap_install() {
  local snap_name="$1"
  local snap_options="${2:-}"

  if ! command -v snap &>/dev/null; then
    show_progress warning "snapd not installed, skipping snap: $snap_name"
    return 0
  fi

  if snap list "$snap_name" &>/dev/null; then
    show_progress info "Snap already installed: $snap_name"
    return 0
  fi

  local wait_attempts=0
  while sudo snap changes | grep -qE "Doing.*auto-refresh"; do
    if [[ $wait_attempts -ge 10 ]]; then
      show_progress error "Snap auto-refresh still running after 20 seconds, skipping: $snap_name"
      return 1
    fi
    show_progress info "Waiting for snap auto-refresh to complete..."
    sleep 2
    wait_attempts=$((wait_attempts + 1))
  done

  if [[ -n "$snap_options" ]]; then
    if sudo snap install "$snap_name" "$snap_options"; then
      show_progress success "Snap installed: $snap_name"
    else
      show_progress warning "Failed to install snap: $snap_name"
      return 1
    fi
  else
    if sudo snap install "$snap_name"; then
      show_progress success "Snap installed: $snap_name"
    else
      show_progress warning "Failed to install snap: $snap_name"
      return 1
    fi
  fi

  return 0
}

# Brief: Configure snap to use system certificates
# Params: None
# Returns: 0 always
# Side-effects: None (informational only)
configure_snap_certificates() {
  command -v snap &>/dev/null || return 0
  systemctl is-active snapd &>/dev/null || return 0

  # Note: Cannot configure snap certificates via command line due to certificate bundle size
  # Snap uses system certificates by default, so custom certs in /usr/local/share/ca-certificates
  # should already be trusted after update-ca-certificates runs
  show_progress info "Snap will use system certificates from /etc/ssl/certs"

  return 0
}

# Brief: Install all snap packages (main entry point)
# Params: None
# Uses: load_snap_packages, SNAP_PACKAGES, SNAP_OPTIONS (functions/global arrays)
# Returns: 0 on success, 1 on failure
# Side-effects: Configures proxy, loads package list, installs snaps
install_snap_packages() {
  show_progress info "Installing snap packages..."

  configure_snap_proxy

  # Load package list from file
  if ! load_snap_packages; then
    show_progress error "Failed to load snap package list"
    return 1
  fi

  local total_packages=${#SNAP_PACKAGES[@]}
  show_progress info "Found $total_packages snap packages to install"
  echo

  # Install each package with its options
  for i in "${!SNAP_PACKAGES[@]}"; do
    local pkg="${SNAP_PACKAGES[$i]}"
    local opts="${SNAP_OPTIONS[$i]}"
    snap_install "$pkg" "$opts"
  done

  echo
  show_progress success "Snap packages installation completed ($total_packages packages)"

  return 0
}
