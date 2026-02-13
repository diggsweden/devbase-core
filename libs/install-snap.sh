#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# App store package installation (snap/flatpak)
# Automatically detects distro and uses appropriate app store

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

if [[ -z "${DEVBASE_DOT:-}" ]]; then
  echo "ERROR: DEVBASE_DOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Detect app store type (cached)
_APP_STORE_TYPE=""

# Brief: Get the app store type for current distro
# Returns: snap, flatpak, or none
_get_app_store_type() {
  if [[ -n "$_APP_STORE_TYPE" ]]; then
    echo "$_APP_STORE_TYPE"
    return
  fi

  if declare -f get_app_store &>/dev/null; then
    _APP_STORE_TYPE=$(get_app_store)
  elif [[ -f "${DEVBASE_ROOT}/libs/distro.sh" ]]; then
    # shellcheck source=distro.sh
    source "${DEVBASE_ROOT}/libs/distro.sh"
    _APP_STORE_TYPE=$(get_app_store)
  else
    # Fallback: detect by available command
    if command -v snap &>/dev/null; then
      _APP_STORE_TYPE="snap"
    elif command -v flatpak &>/dev/null; then
      _APP_STORE_TYPE="flatpak"
    else
      _APP_STORE_TYPE="none"
    fi
  fi

  echo "$_APP_STORE_TYPE"
}

# =============================================================================
# SNAP IMPLEMENTATION
# =============================================================================

# Brief: Read snap package list from packages.yaml
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_SELECTED_PACKS, get_snap_packages (globals/functions)
# Returns: 0 on success, 1 if no packages found
# Outputs: Arrays of package names and options to global SNAP_PACKAGES and SNAP_OPTIONS
# Side-effects: Populates SNAP_PACKAGES and SNAP_OPTIONS arrays
load_snap_packages() {
  # Source parser if not already loaded
  if ! declare -f get_snap_packages &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  _setup_package_yaml_env || return 1

  # Get packages from parser (format: "name|options")
  local packages=()
  local options=()

  while IFS='|' read -r pkg opts; do
    [[ -z "$pkg" ]] && continue
    packages+=("$pkg")
    options+=("$opts")
  done < <(get_snap_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress warning "No snap packages found in configuration"
    return 0
  fi

  # Export as readonly arrays
  readonly SNAP_PACKAGES=("${packages[@]}")
  readonly SNAP_OPTIONS=("${options[@]}")

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

  # Install with gum spinner or whiptail
  # Note: snap_options intentionally unquoted to allow word splitting (e.g., "--classic")
  local install_result
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    if [[ -n "$snap_options" ]]; then
      # shellcheck disable=SC2086
      gum spin --spinner dot --show-error --title "Installing snap: $snap_name..." -- \
        sudo snap install "$snap_name" $snap_options
      install_result=$?
    else
      gum spin --spinner dot --show-error --title "Installing snap: $snap_name..." -- \
        sudo snap install "$snap_name"
      install_result=$?
    fi
  else
    # Whiptail mode (default)
    if [[ -n "$snap_options" ]]; then
      # shellcheck disable=SC2086
      run_with_spinner "Installing snap: $snap_name" sudo snap install "$snap_name" $snap_options
      install_result=$?
    else
      run_with_spinner "Installing snap: $snap_name" sudo snap install "$snap_name"
      install_result=$?
    fi
  fi

  if [[ $install_result -eq 0 ]]; then
    show_progress success "Snap installed: $snap_name"
  else
    show_progress warning "Failed to install snap: $snap_name"
    return 1
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

# Brief: Install all snap packages
# Params: None
# Uses: load_snap_packages, SNAP_PACKAGES, SNAP_OPTIONS (functions/global arrays)
# Returns: 0 on success, 1 on failure
# Side-effects: Loads package list, installs snaps
_install_snap_packages() {
  show_progress info "Installing snap packages..."

  # Load package list from file
  if ! load_snap_packages; then
    show_progress error "Failed to load snap package list"
    return 1
  fi

  local total_packages=${#SNAP_PACKAGES[@]}
  show_progress info "Found $total_packages snap packages to install"
  tui_blank_line

  # Install each package with its options
  # Track progress for whiptail mode with persistent gauge
  local installed_count=0

  for i in "${!SNAP_PACKAGES[@]}"; do
    local pkg="${SNAP_PACKAGES[$i]}"
    local opts="${SNAP_OPTIONS[$i]}"

    # Update gauge before installing (whiptail mode only)
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && _wt_gauge_is_running; then
      local percent=$(((installed_count * 100) / total_packages))
      _wt_update_gauge "Installing snap: $pkg ($((installed_count + 1))/$total_packages)" "$percent"
    fi

    snap_install "$pkg" "$opts"
    installed_count=$((installed_count + 1))

    # Update gauge after installing (whiptail mode only)
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && _wt_gauge_is_running; then
      local percent=$(((installed_count * 100) / total_packages))
      _wt_update_gauge "Installed snap: $pkg ($installed_count/$total_packages)" "$percent"
    fi
  done

  tui_blank_line
  show_progress success "Snap packages installation completed ($total_packages packages)"

  return 0
}

# =============================================================================
# FLATPAK IMPLEMENTATION
# =============================================================================

# Brief: Read flatpak package list from packages.yaml
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_SELECTED_PACKS, get_flatpak_packages (globals/functions)
# Returns: 0 on success
# Outputs: Arrays to FLATPAK_PACKAGES and FLATPAK_REMOTES
load_flatpak_packages() {
  # Source parser if not already loaded
  if ! declare -f get_flatpak_packages &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  _setup_package_yaml_env || return 1

  # Get packages from parser (format: "app_id|remote")
  local packages=()
  local remotes=()

  while IFS='|' read -r app_id remote; do
    [[ -z "$app_id" ]] && continue
    packages+=("$app_id")
    remotes+=("${remote:-flathub}")
  done < <(get_flatpak_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    show_progress warning "No flatpak packages found in configuration"
    return 0
  fi

  # Export as readonly arrays
  readonly FLATPAK_PACKAGES=("${packages[@]}")
  readonly FLATPAK_REMOTES=("${remotes[@]}")

  return 0
}

# Brief: Ensure Flathub remote is configured
# Params: None
# Returns: 0 on success, 1 on failure
configure_flathub() {
  if ! command -v flatpak &>/dev/null; then
    show_progress warning "flatpak not installed"
    return 1
  fi

  # Check if flathub is already configured
  if flatpak remotes --user 2>/dev/null | grep -q "^flathub"; then
    return 0
  fi
  if flatpak remotes --system 2>/dev/null | grep -q "^flathub"; then
    return 0
  fi

  # Add flathub for user
  show_progress info "Adding Flathub repository..."
  if flatpak remote-add --user --if-not-exists flathub "https://dl.flathub.org/repo/flathub.flatpakrepo"; then
    show_progress success "Flathub repository added"
    return 0
  else
    show_progress warning "Failed to add Flathub repository"
    return 1
  fi
}

# Brief: Install flatpak package
# Params: $1 - app_id, $2 - remote (optional, defaults to flathub)
# Returns: 0 on success, 1 on failure
flatpak_install() {
  local app_id="$1"
  local remote="${2:-flathub}"

  if ! command -v flatpak &>/dev/null; then
    show_progress warning "flatpak not installed, skipping: $app_id"
    return 0
  fi

  # Check if already installed
  if flatpak list --app 2>/dev/null | grep -q "$app_id"; then
    show_progress info "Flatpak already installed: $app_id"
    return 0
  fi

  # Install with gum spinner or whiptail
  local install_result
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum spin --spinner dot --show-error --title "Installing flatpak: $app_id..." -- \
      flatpak install -y --user "$remote" "$app_id"
    install_result=$?
  else
    run_with_spinner "Installing flatpak: $app_id" flatpak install -y --user "$remote" "$app_id"
    install_result=$?
  fi

  if [[ $install_result -eq 0 ]]; then
    show_progress success "Flatpak installed: $app_id"
  else
    show_progress warning "Failed to install flatpak: $app_id"
    return 1
  fi

  return 0
}

# Brief: Install all flatpak packages
# Params: None
# Returns: 0 on success, 1 on failure
_install_flatpak_packages() {
  show_progress info "Installing flatpak packages..."

  # Ensure flathub is configured
  configure_flathub || return 1

  # Load package list from file
  if ! load_flatpak_packages; then
    show_progress error "Failed to load flatpak package list"
    return 1
  fi

  local total_packages=${#FLATPAK_PACKAGES[@]}
  show_progress info "Found $total_packages flatpak packages to install"
  tui_blank_line

  # Install each package
  for i in "${!FLATPAK_PACKAGES[@]}"; do
    local app_id="${FLATPAK_PACKAGES[$i]}"
    local remote="${FLATPAK_REMOTES[$i]}"
    flatpak_install "$app_id" "$remote"
  done

  tui_blank_line
  show_progress success "Flatpak packages installation completed ($total_packages packages)"

  return 0
}

# =============================================================================
# UNIFIED INTERFACE
# =============================================================================

# Brief: Install app store packages (snap or flatpak based on distro)
# Params: None
# Returns: 0 on success, 1 on failure
install_app_store_packages() {
  local app_store
  app_store=$(_get_app_store_type)

  case "$app_store" in
  snap)
    _install_snap_packages
    ;;
  flatpak)
    _install_flatpak_packages
    ;;
  none)
    show_progress info "No app store available (WSL or unsupported distro)"
    return 0
    ;;
  *)
    show_progress warning "Unknown app store type: $app_store"
    return 1
    ;;
  esac
}

# Backward compatibility alias
install_snap_packages() {
  install_app_store_packages
}
