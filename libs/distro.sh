#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Distro detection and helper functions for multi-distribution support
# Supported distros: ubuntu, ubuntu-wsl, fedora (experimental)

set -uo pipefail

# =============================================================================
# DISTRO DETECTION
# =============================================================================

# Brief: Check if running in WSL
# Returns: 0 if WSL, 1 otherwise
is_wsl() {
  # Check environment variables (set by WSL)
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]]; then
    return 0
  fi

  # Check binfmt_misc indicator
  if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    return 0
  fi

  # Check /proc/version for "microsoft" string
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    return 0
  fi

  return 1
}

# Brief: Get the Linux distribution ID
# Returns: ubuntu, ubuntu-wsl, fedora, unknown
get_distro() {
  local distro_id

  # Read from os-release
  if [[ -f /etc/os-release ]]; then
    distro_id=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
  else
    echo "unknown"
    return 1
  fi

  # Normalize and handle WSL
  case "$distro_id" in
  ubuntu)
    if is_wsl; then
      echo "ubuntu-wsl"
    else
      echo "ubuntu"
    fi
    ;;
  fedora)
    echo "fedora"
    ;;
  debian)
    # Treat Debian like Ubuntu for now
    if is_wsl; then
      echo "ubuntu-wsl"
    else
      echo "ubuntu"
    fi
    ;;
  *)
    echo "unknown"
    return 1
    ;;
  esac
}

# Brief: Get the distribution family (for package format)
# Returns: debian, redhat, unknown
get_distro_family() {
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu | ubuntu-wsl)
    echo "debian"
    ;;
  fedora)
    echo "redhat"
    ;;
  *)
    echo "unknown"
    return 1
    ;;
  esac
}

# Brief: Get the package manager command
# Returns: apt, dnf
get_pkg_manager() {
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu | ubuntu-wsl)
    echo "apt"
    ;;
  fedora)
    echo "dnf"
    ;;
  *)
    # Fallback: detect by available command
    if command -v apt &>/dev/null; then
      echo "apt"
    elif command -v dnf &>/dev/null; then
      echo "dnf"
    else
      echo "unknown"
      return 1
    fi
    ;;
  esac
}

# Brief: Get the package format
# Returns: deb, rpm
get_pkg_format() {
  local family
  family=$(get_distro_family)

  case "$family" in
  debian)
    echo "deb"
    ;;
  redhat)
    echo "rpm"
    ;;
  *)
    echo "unknown"
    return 1
    ;;
  esac
}

# Brief: Get the Debian-style architecture name for the current machine
# Returns: amd64, arm64, armhf, i386, or exits with error
get_deb_arch() {
  case "$(uname -m)" in
  x86_64) echo "amd64" ;;
  aarch64) echo "arm64" ;;
  armv7l) echo "armhf" ;;
  i686) echo "i386" ;;
  *)
    echo "unknown"
    return 1
    ;;
  esac
}

# Brief: Get the RPM-style architecture name for the current machine
# Returns: x86_64, aarch64, armv7hl, i686, or exits with error
get_rpm_arch() {
  case "$(uname -m)" in
  x86_64) echo "x86_64" ;;
  aarch64) echo "aarch64" ;;
  armv7l) echo "armv7hl" ;;
  i686) echo "i686" ;;
  *)
    echo "unknown"
    return 1
    ;;
  esac
}

# Brief: Get the app store type
# Returns: snap, flatpak, none
get_app_store() {
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu)
    echo "snap"
    ;;
  ubuntu-wsl)
    echo "none"
    ;;
  fedora)
    echo "flatpak"
    ;;
  *)
    echo "none"
    ;;
  esac
}

# Brief: Get the firewall tool
# Returns: ufw, firewalld, none
get_firewall() {
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu)
    echo "ufw"
    ;;
  ubuntu-wsl)
    echo "none"
    ;;
  fedora)
    echo "firewalld"
    ;;
  *)
    echo "none"
    ;;
  esac
}

# Brief: Check if systemd is available and running
# Returns: 0 if available, 1 otherwise
has_systemd() {
  [[ -d /run/systemd/system ]]
}

# Brief: Check if we can install desktop apps
# Returns: 0 if desktop environment available, 1 otherwise
has_desktop() {
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu-wsl)
    # WSLg may be available
    [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]
    ;;
  *)
    # Native Linux with display
    [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]
    ;;
  esac
}

# Brief: Get distro-specific package name
# Params: $1 - generic package name
# Returns: distro-specific package name
get_pkg_name() {
  local generic_name="$1"
  local distro
  distro=$(get_distro)

  # Package name mappings (generic -> distro-specific)
  case "$generic_name" in
  build-essential)
    case "$distro" in
    ubuntu | ubuntu-wsl) echo "build-essential" ;;
    fedora) echo "@development-tools" ;;
    esac
    ;;
  libnss3-tools)
    case "$distro" in
    ubuntu | ubuntu-wsl) echo "libnss3-tools" ;;
    fedora) echo "nss-tools" ;;
    esac
    ;;
  openssh-client)
    case "$distro" in
    ubuntu | ubuntu-wsl) echo "openssh-client" ;;
    fedora) echo "openssh-clients" ;;
    esac
    ;;
  dnsutils)
    case "$distro" in
    ubuntu | ubuntu-wsl) echo "dnsutils" ;;
    fedora) echo "bind-utils" ;;
    esac
    ;;
  # Development libraries: -dev -> -devel
  *-dev)
    case "$distro" in
    ubuntu | ubuntu-wsl) echo "$generic_name" ;;
    fedora) echo "${generic_name%-dev}-devel" ;;
    esac
    ;;
  # Default: return as-is
  *)
    echo "$generic_name"
    ;;
  esac
}

# Brief: Print distro info for debugging
print_distro_info() {
  echo "Distro:      $(get_distro)"
  echo "Family:      $(get_distro_family)"
  echo "Pkg Manager: $(get_pkg_manager)"
  echo "Pkg Format:  $(get_pkg_format)"
  echo "App Store:   $(get_app_store)"
  echo "Firewall:    $(get_firewall)"
  echo "WSL:         $(is_wsl && echo "yes" || echo "no")"
  echo "Systemd:     $(has_systemd && echo "yes" || echo "no")"
  echo "Desktop:     $(has_desktop && echo "yes" || echo "no")"
}
