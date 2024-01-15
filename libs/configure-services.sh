#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
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

# Brief: Configure UFW firewall with k3s rules if applicable
# Params: None
# Uses: show_progress (from ui-helpers)
# Returns: 0 on success or if skipped, 1 if enable fails
# Side-effects: Adds firewall rules for k3s if installed, enables UFW, skips on WSL
configure_ufw() {
  if ! command -v ufw &>/dev/null; then
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    show_progress info "[WSL-specific] WSL detected - skipping UFW (use Windows Firewall)"
    return 0
  fi

  show_progress info "Configuring UFW firewall..."

  # Allow k3s traffic if k3s is installed
  # k3s requires these ports to function properly:
  # - 6443/tcp: Kubernetes API server
  # - 10.42.0.0/16: Pod network (default flannel CIDR)
  # - 10.43.0.0/16: Service network (default ClusterIP CIDR)
  if command -v k3s &>/dev/null; then
    sudo ufw allow 6443/tcp comment 'k3s apiserver' &>/dev/null
    sudo ufw allow from 10.42.0.0/16 to any comment 'k3s pods' &>/dev/null
    sudo ufw allow from 10.43.0.0/16 to any comment 'k3s services' &>/dev/null
    show_progress info "Added k3s firewall rules"
  fi

  if sudo ufw --force enable &>/dev/null; then
    show_progress success "UFW firewall enabled and activated"
  else
    show_progress warning "Failed to enable UFW firewall"
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

  if [[ ! -f "$sysctl_file" ]] || ! grep -q "fs.file-max" "$sysctl_file" 2>/dev/null; then
    echo "fs.file-max = 90000" | sudo tee "$sysctl_file" >/dev/null
  fi

  show_progress success "System limits configured (nofile: 65536, nproc: 32768, fs.file-max: 90000)"
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

  if sudo systemctl enable clamav-freshclam.service; then
    sudo systemctl start clamav-freshclam.service || true
    show_progress success "ClamAV freshclam enabled"
  else
    show_progress warning "Failed to enable clamav-freshclam service"
  fi

  if [[ -d "$source_dir" ]]; then
    if sudo cp "$source_dir"/*.{service,timer} "$systemd_dir"/ 2>/dev/null; then
      sudo systemctl daemon-reload
      if sudo systemctl enable clamav-daily-scan.timer; then
        if sudo systemctl start clamav-daily-scan.timer; then
          show_progress success "ClamAV daily scan enabled and started (runs 2-4 AM)"
        else
          show_progress warning "ClamAV daily scan enabled (will start on next boot)"
        fi
      else
        show_progress error "Failed to enable ClamAV daily scan"
        return 1
      fi
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
    if sudo systemctl stop k3s; then
      sudo systemctl disable k3s || true
      show_progress success "K3s disabled (enable with: sudo systemctl enable --now k3s)"
    fi
  fi

  # Disable MicroK8s if installed
  if command -v microk8s &>/dev/null; then
    if sudo snap stop microk8s; then
      sudo systemctl disable snap.microk8s.daemon-kubelite || true
      show_progress success "MicroK8s disabled (enable with: sudo systemctl enable --now snap.microk8s.daemon-kubelite)"
    fi
  fi

  return 0
}
