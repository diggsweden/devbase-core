#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Enable and start a systemd user service
# Params: $1 - service_name, $2 - service description (optional, default: service_name)
# Uses: show_progress (from ui-helpers)
# Returns: 0 on success, 1 if enable fails
# Side-effects: Reloads systemd daemon, enables and starts service
enable_user_service() {
  local service_name="$1"
  local service_desc="${2:-$service_name}"

  validate_not_empty "$service_name" "Service name" || return 1

  systemctl --user daemon-reload || show_progress warning "Failed to reload systemd user daemon"

  if systemctl --user enable "$service_name"; then
    if systemctl --user start "$service_name"; then
      show_progress success "${service_desc} enabled and started"
    else
      show_progress warning "${service_desc} enabled but not started"
    fi
  else
    show_progress warning "Failed to enable ${service_desc}"
    return 1
  fi
  return 0
}

# Brief: Configure firewall with k3s rules if applicable (UFW or firewalld)
# Params: None
# Uses: show_progress, get_firewall (from ui-helpers, distro.sh)
# Returns: 0 on success or if skipped, 1 if enable fails
# Side-effects: Adds firewall rules for k3s if installed, enables firewall, skips on WSL
configure_ufw() {
  # Detect firewall type
  local firewall_type
  if declare -f get_firewall &>/dev/null; then
    firewall_type=$(get_firewall)
  elif command -v ufw &>/dev/null; then
    firewall_type="ufw"
  elif command -v firewall-cmd &>/dev/null; then
    firewall_type="firewalld"
  else
    firewall_type="none"
  fi

  if [[ "$firewall_type" == "none" ]]; then
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    show_progress info "[WSL-specific] WSL detected - skipping firewall (use Windows Firewall)"
    return 0
  fi

  case "$firewall_type" in
  ufw)
    _configure_ufw_firewall
    ;;
  firewalld)
    _configure_firewalld
    ;;
  esac
}

# Brief: Configure UFW firewall (Ubuntu/Debian)
_configure_ufw_firewall() {
  show_progress info "Configuring UFW firewall..."

  # Allow k3s traffic if k3s is installed
  if command -v k3s &>/dev/null; then
    sudo ufw allow from 127.0.0.1 to any port 6443 proto tcp comment 'k3s apiserver (localhost)' &>/dev/null
    sudo ufw allow from 10.42.0.0/16 to any comment 'k3s pods' &>/dev/null
    sudo ufw allow from 10.43.0.0/16 to any comment 'k3s services' &>/dev/null
    show_progress info "Added k3s firewall rules (API restricted to localhost)"
  fi

  if sudo ufw --force enable &>/dev/null; then
    show_progress success "UFW firewall enabled and activated"
  else
    show_progress warning "Failed to enable UFW firewall"
    return 1
  fi

  return 0
}

# Brief: Configure firewalld (Fedora/RHEL)
_configure_firewalld() {
  show_progress info "Configuring firewalld..."

  # Allow k3s traffic if k3s is installed
  if command -v k3s &>/dev/null; then
    # Add k3s ports to trusted zone for localhost
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port protocol="tcp" port="6443" accept' &>/dev/null || true
    # Allow pod and service networks
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.42.0.0/16" accept' &>/dev/null || true
    sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.43.0.0/16" accept' &>/dev/null || true
    show_progress info "Added k3s firewall rules (API restricted to localhost)"
  fi

  # Reload to apply changes
  if sudo firewall-cmd --reload &>/dev/null; then
    show_progress success "firewalld configured and reloaded"
  else
    show_progress warning "Failed to reload firewalld"
    return 1
  fi

  return 0
}

# Brief: Configure system resource limits for development
# Params: None
# Uses: show_progress (from ui-helpers)
# Returns: 0 always
# Side-effects: Creates /etc/security/limits.d/99-devbase.conf and /etc/sysctl.d/99-devbase.conf with sudo
set_system_limits() {
  show_progress info "Configuring system limits..."

  local limits_file="/etc/security/limits.d/99-devbase.conf"
  local sysctl_file="/etc/sysctl.d/99-devbase.conf"

  sudo tee "$limits_file" &>/dev/null <<'EOF'
# DevBase development limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
* soft memlock unlimited
* hard memlock unlimited
EOF

  sudo bash -c "cat > '$sysctl_file'" <<'EOF'
# DevBase kernel parameters
fs.file-max = 90000
vm.swappiness = 5
EOF

  sudo sysctl -p "$sysctl_file" &>/dev/null || true

  show_progress success "System limits configured (nofile: 65536, nproc: 32768, fs.file-max: 90000, swappiness: 5)"
  return 0
}

# Brief: Enable Podman socket service if Podman is installed
# Params: None
# Uses: show_progress, enable_user_service (functions)
# Returns: 0 always
# Side-effects: Enables podman.socket user service
configure_podman_service() {
  if ! command -v podman &>/dev/null; then
    return 0
  fi

  show_progress info "Configuring Podman service..."

  enable_user_service "podman.socket" "Podman service" || true

  return 0
}

# Brief: Enable Wayland socket symlink service if configured
# Params: None
# Uses: XDG_CONFIG_HOME, show_progress, enable_user_service (globals/functions)
# Returns: 0 always
# Side-effects: Reloads systemd daemon, enables wayland-socket-symlink.service
configure_wayland_service() {
  validate_var_set "XDG_CONFIG_HOME" || return 1

  local service_file="$XDG_CONFIG_HOME/systemd/user/wayland-socket-symlink.service"

  if [[ ! -f "$service_file" ]]; then
    return 0
  fi

  show_progress info "Configuring Wayland service..."

  # Reload daemon to pick up any template changes
  systemctl --user daemon-reload || show_progress warning "Failed to reload systemd user daemon"

  enable_user_service "wayland-socket-symlink.service" "Wayland service" || show_progress warning "Failed to enable Wayland service"

  return 0
}

# Brief: Configure ClamAV antivirus service with freshclam and daily scanning
# Params: None
# Uses: DEVBASE_FILES, show_progress (globals/functions)
# Returns: 0 on success, 1 if daily scan enable fails
# Side-effects: Enables clamav-freshclam service, copies timer/service files, enables daily scan timer, disables persistent daemon socket
configure_clamav_service() {
  validate_var_set "DEVBASE_FILES" || return 1

  if ! command -v clamscan &>/dev/null; then
    return 0
  fi

  show_progress info "Configuring ClamAV scanning..."

  local systemd_dir="/etc/systemd/system"
  local source_dir="${DEVBASE_FILES}/systemd/clamav"

  # Disable Ubuntu's default socket-activated daemon to prevent 24/7 resource usage
  # The daemon will only run during scheduled scans (2-4 AM)
  if systemctl is-enabled clamav-daemon.socket &>/dev/null; then
    sudo systemctl disable --now clamav-daemon.socket &>/dev/null || true
    sudo systemctl disable clamav-daemon.service &>/dev/null || true
    show_progress success "Disabled ClamAV persistent daemon (will run only during scheduled scans)"
  fi

  systemctl_enable_start "clamav-freshclam.service" "ClamAV freshclam"

  if [[ -d "$source_dir" ]]; then
    if sudo cp "$source_dir"/*.{service,timer} "$systemd_dir"/ 2>/dev/null; then
      sudo systemctl daemon-reload >/dev/null 2>&1
      systemctl_enable_start "clamav-daily-scan.timer" "ClamAV daily scan (runs 2-4 AM)" || {
        show_progress error "Failed to enable ClamAV daily scan"
        return 1
      }
    else
      show_progress warning "ClamAV service files not found"
    fi
  else
    show_progress warning "ClamAV systemd files directory not found"
  fi

  return 0
}

# Brief: Disable Kubernetes services (K3s and MicroK8s) to save resources
# Params: None
# Uses: show_progress (from ui-helpers)
# Returns: 0 always
# Side-effects: Stops and disables k3s and microk8s services if installed
disable_kubernetes_services() {
  show_progress info "Disabling Kubernetes services (enable manually when needed)..."

  if command -v k3s &>/dev/null; then
    systemctl_disable_stop "k3s" "K3s (enable with: sudo systemctl enable --now k3s)"
  fi

  # Disable MicroK8s if installed
  if command -v microk8s &>/dev/null; then
    if sudo snap stop microk8s >/dev/null 2>&1; then
      systemctl_disable_stop "snap.microk8s.daemon-kubelite" "MicroK8s (enable with: sudo systemctl enable --now snap.microk8s.daemon-kubelite)"
    fi
  fi

  return 0
}
