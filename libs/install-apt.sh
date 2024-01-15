#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

readonly APT_PACKAGES_CORE=(
  git curl wget apt-utils locales
)

readonly APT_PACKAGES_BUILD=(
  build-essential python3-dev
)

readonly APT_PACKAGES_SHELL=(
  fish bash-completion vifm tree
)

readonly APT_PACKAGES_CONTAINERS=(
  podman buildah skopeo containernetworking-plugins
)

readonly APT_PACKAGES_SECURITY=(
  clamav clamav-daemon unattended-upgrades lynis ufw gufw
)

readonly APT_PACKAGES_GUI=(
  xdg-desktop-portal-gtk desktop-file-utils libgbm1
  libxi6 libxrender1 libxtst6 mesa-utils libfontconfig libgtk-3-bin tar dbus-user-session
)

readonly APT_PACKAGES_DEV=(
  yadm dnsutils e2fsprogs pwgen pandoc parallel jq w3m
)

readonly APT_PACKAGES_JAVA=(
  default-jre default-jdk visualvm
)

readonly APT_PACKAGES_SSH=(
  libnss3-tools mkcert openssh-client ssh-askpass
)

readonly APT_PACKAGES_PYTHON=(
  python3 python3-venv
)

readonly APT_PACKAGES_RUBY=(
  libyaml-dev libffi-dev libreadline-dev zlib1g-dev libgdbm-dev libncurses-dev libssl-dev
)

readonly APT_PACKAGES_RUST=(
  pkg-config libssl-dev libsqlite3-dev
)

readonly APT_PACKAGES_NON_WSL=(
  tlp tlp-rdw # Power management for laptops
  dislocker   # BitLocker drive support (NTFS encrypted volumes)
)

readonly APT_PACKAGES_OTHER=(
  bleachbit # System cleaner and privacy tool
)

# Build package list dynamically based on environment
APT_PACKAGES_ALL=(
  "${APT_PACKAGES_CORE[@]}"
  "${APT_PACKAGES_BUILD[@]}"
  "${APT_PACKAGES_SHELL[@]}"
  "${APT_PACKAGES_CONTAINERS[@]}"
  "${APT_PACKAGES_SECURITY[@]}"
  "${APT_PACKAGES_GUI[@]}"
  "${APT_PACKAGES_DEV[@]}"
  "${APT_PACKAGES_JAVA[@]}"
  "${APT_PACKAGES_SSH[@]}"
  "${APT_PACKAGES_PYTHON[@]}"
  "${APT_PACKAGES_RUBY[@]}"
  "${APT_PACKAGES_RUST[@]}"
  "${APT_PACKAGES_OTHER[@]}"
)

# Add packages for non-WSL systems only
# WSL accesses Windows drives directly, doesn't need TLP or dislocker
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  APT_PACKAGES_ALL+=("${APT_PACKAGES_NON_WSL[@]}")
fi

readonly APT_PACKAGES_ALL

# Brief: Update APT package cache
# Params: None
# Returns: 0 on success, non-zero on failure
# Side-effects: Updates APT cache
pkg_update() {
  retry_command sudo apt-get -q update
  return 0
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

  retry_command sudo apt-get -y -q install "${packages[@]}"
  return 0
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

# Brief: Install Microsoft core fonts with EULA auto-acceptance
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Installs fonts, rebuilds font cache
install_ms_core_fonts() {
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections 2>/dev/null

  if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q ttf-mscorefonts-installer; then
    command -v fc-cache &>/dev/null && fc-cache -f
    return 0
  fi

  return 1
}

# Brief: Install all APT packages, configure locale, and install fonts
# Params: None
# Uses: APT_PACKAGES_ALL (global array)
# Returns: 0 on success, 1 on failure
# Side-effects: Installs packages, configures locale, cleans up
install_apt_packages() {
  local total_packages=${#APT_PACKAGES_ALL[@]}
  show_progress info "Installing system packages..."
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
  if install_ms_core_fonts; then
    fonts_installed=true
  fi

  local msg="System packages installed (${total_packages} packages"
  [[ -n "$locale_configured" ]] && msg="${msg}, locale: ${locale_configured}"
  [[ "$fonts_installed" == true ]] && msg="${msg}, MS fonts"
  msg="${msg})"

  echo
  show_progress success "$msg"

  return 0
}
