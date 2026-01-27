#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2329
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for libs/distro.sh - Distribution detection and helper functions

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  source "${DEVBASE_ROOT}/libs/distro.sh"
}

# =============================================================================
# is_wsl tests
# =============================================================================

@test "is_wsl returns false on native Linux" {
  # Skip if actually running on WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    skip "Running on WSL"
  fi
  
  run is_wsl
  assert_failure
}

# =============================================================================
# get_distro tests
# =============================================================================

@test "get_distro returns valid distro name" {
  run get_distro
  assert_success
  # Should be one of the known distros
  [[ "$output" =~ ^(ubuntu|ubuntu-wsl|fedora|unknown)$ ]]
}

@test "get_distro returns ubuntu on Ubuntu" {
  # Skip if not Ubuntu
  if ! grep -q "^ID=ubuntu" /etc/os-release 2>/dev/null; then
    skip "Not running on Ubuntu"
  fi
  if grep -qi microsoft /proc/version 2>/dev/null; then
    skip "Running on WSL"
  fi
  
  run get_distro
  assert_success
  assert_output "ubuntu"
}

@test "get_distro returns ubuntu-wsl on WSL" {
  # Skip if not WSL
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    skip "Not running on WSL"
  fi
  
  run get_distro
  assert_success
  assert_output "ubuntu-wsl"
}

@test "get_distro returns fedora on Fedora" {
  # Skip if not Fedora
  if ! grep -q "^ID=fedora" /etc/os-release 2>/dev/null; then
    skip "Not running on Fedora"
  fi
  
  run get_distro
  assert_success
  assert_output "fedora"
}

# =============================================================================
# get_distro_family tests
# =============================================================================

@test "get_distro_family returns debian for ubuntu" {
  # Mock get_distro
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_distro_family
  assert_success
  assert_output "debian"
}

@test "get_distro_family returns debian for ubuntu-wsl" {
  get_distro() { echo "ubuntu-wsl"; }
  export -f get_distro
  
  run get_distro_family
  assert_success
  assert_output "debian"
}

@test "get_distro_family returns redhat for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_distro_family
  assert_success
  assert_output "redhat"
}

# =============================================================================
# get_pkg_manager tests
# =============================================================================

@test "get_pkg_manager returns apt for ubuntu" {
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_pkg_manager
  assert_success
  assert_output "apt"
}

@test "get_pkg_manager returns apt for ubuntu-wsl" {
  get_distro() { echo "ubuntu-wsl"; }
  export -f get_distro
  
  run get_pkg_manager
  assert_success
  assert_output "apt"
}

@test "get_pkg_manager returns dnf for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_manager
  assert_success
  assert_output "dnf"
}

# =============================================================================
# get_pkg_format tests
# =============================================================================

@test "get_pkg_format returns deb for debian family" {
  get_distro_family() { echo "debian"; }
  export -f get_distro_family
  
  run get_pkg_format
  assert_success
  assert_output "deb"
}

@test "get_pkg_format returns rpm for redhat family" {
  get_distro_family() { echo "redhat"; }
  export -f get_distro_family
  
  run get_pkg_format
  assert_success
  assert_output "rpm"
}

# =============================================================================
# get_app_store tests
# =============================================================================

@test "get_app_store returns snap for ubuntu" {
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_app_store
  assert_success
  assert_output "snap"
}

@test "get_app_store returns none for ubuntu-wsl" {
  get_distro() { echo "ubuntu-wsl"; }
  export -f get_distro
  
  run get_app_store
  assert_success
  assert_output "none"
}

@test "get_app_store returns flatpak for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_app_store
  assert_success
  assert_output "flatpak"
}

# =============================================================================
# get_firewall tests
# =============================================================================

@test "get_firewall returns ufw for ubuntu" {
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_firewall
  assert_success
  assert_output "ufw"
}

@test "get_firewall returns none for ubuntu-wsl" {
  get_distro() { echo "ubuntu-wsl"; }
  export -f get_distro
  
  run get_firewall
  assert_success
  assert_output "none"
}

@test "get_firewall returns firewalld for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_firewall
  assert_success
  assert_output "firewalld"
}

# =============================================================================
# get_pkg_name tests
# =============================================================================

@test "get_pkg_name returns build-essential for ubuntu" {
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_pkg_name "build-essential"
  assert_success
  assert_output "build-essential"
}

@test "get_pkg_name returns @development-tools for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "build-essential"
  assert_success
  assert_output "@development-tools"
}

@test "get_pkg_name converts -dev to -devel for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "libffi-dev"
  assert_success
  assert_output "libffi-devel"
}

@test "get_pkg_name keeps -dev for ubuntu" {
  get_distro() { echo "ubuntu"; }
  export -f get_distro
  
  run get_pkg_name "libffi-dev"
  assert_success
  assert_output "libffi-dev"
}

@test "get_pkg_name maps libnss3-tools to nss-tools for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "libnss3-tools"
  assert_success
  assert_output "nss-tools"
}

@test "get_pkg_name maps openssh-client to openssh-clients for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "openssh-client"
  assert_success
  assert_output "openssh-clients"
}

@test "get_pkg_name maps dnsutils to bind-utils for fedora" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "dnsutils"
  assert_success
  assert_output "bind-utils"
}

@test "get_pkg_name returns unchanged for common packages" {
  get_distro() { echo "fedora"; }
  export -f get_distro
  
  run get_pkg_name "curl"
  assert_success
  assert_output "curl"
}

# =============================================================================
# has_systemd tests
# =============================================================================

@test "has_systemd returns success when systemd running" {
  if [[ ! -d /run/systemd/system ]]; then
    skip "Systemd not running"
  fi
  
  run has_systemd
  assert_success
}

# =============================================================================
# print_distro_info tests
# =============================================================================

@test "print_distro_info outputs all fields" {
  run print_distro_info
  assert_success
  assert_output --partial "Distro:"
  assert_output --partial "Family:"
  assert_output --partial "Pkg Manager:"
  assert_output --partial "Pkg Format:"
  assert_output --partial "App Store:"
  assert_output --partial "Firewall:"
  assert_output --partial "WSL:"
  assert_output --partial "Systemd:"
  assert_output --partial "Desktop:"
}
