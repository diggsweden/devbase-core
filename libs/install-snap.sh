#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# Brief: Configure snap package manager proxy settings
# Params: None
# Uses: DEVBASE_PROXY_URL (global, optional)
# Returns: 0 always
# Side-effects: Sets snap system proxy configuration
configure_snap_proxy() {
  [[ -z "${DEVBASE_PROXY_URL:-}" ]] && return 0
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
# Returns: 0 always
# Side-effects: Configures proxy, installs multiple snaps
install_snap_packages() {
  configure_snap_proxy

  snap_install "ghostty" "--classic"
  snap_install "firefox"
  snap_install "chromium"
  snap_install "microk8s" "--classic"

  return 0
}
