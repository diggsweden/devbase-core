#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

show_welcome_banner() {
  require_env DEVBASE_TUI_MODE || return 1

  local devbase_version
  local git_sha

  read -r devbase_version git_sha <<<"$(resolve_devbase_version)"

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    echo
    gum style \
      --foreground 212 \
      --border double \
      --border-foreground 212 \
      --padding "1 4" \
      --margin "1 0" \
      --align center \
      "DevBase Core Installation" \
      "" \
      "Version: $devbase_version ($git_sha)" \
      "Started: $(date +"%H:%M:%S")"
    echo
    gum style --foreground 240 --align center \
      "Development environment setup wizard"
    gum style --foreground 240 \
      "j/k navigate  SPACE toggle  ENTER select  Ctrl+C cancel"
    echo
  else
    # Whiptail mode (default) - show welcome infobox
    clear
    whiptail --backtitle "$WT_BACKTITLE" --title "DevBase Core Installation" \
      --infobox "Version: $devbase_version ($git_sha)\nStarted: $(date +"%H:%M:%S")\n\nInitializing..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
  fi
}

show_os_info() {
  require_env DEVBASE_TUI_MODE || return 1

  local os_name env_type install_type

  os_name=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
  env_type=$([[ "${_DEVBASE_ENV:-}" == "wsl-ubuntu" ]] && echo "WSL" || echo "Native Linux")
  install_type=$([[ "${_DEVBASE_FROM_GIT:-}" == "true" ]] && echo "Git repository" || echo "Downloaded")

  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    gum style --foreground 240 "System Information"
    echo "  OS:           $os_name"
    echo "  Environment:  $env_type"
    echo "  Installation: $install_type"
    echo "  User:         $USER"
    echo "  Home:         $HOME"
    echo
  else
    # Whiptail mode - show system info infobox
    whiptail --backtitle "$WT_BACKTITLE" --title "System Information" \
      --infobox "OS: $os_name\nEnvironment: $env_type\nUser: $USER\n\nLoading configuration..." "$WT_HEIGHT_SMALL" "$WT_WIDTH"
    sleep 1
  fi
}

show_repository_info() {
  require_env DEVBASE_TUI_MODE || return 1

  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then

    # Silent in whiptail mode - info shown in whiptail dialogs
    return 0
  fi
  # shellcheck disable=SC2153 # DEVBASE_ROOT set by init_env
  echo "  Running from: $DEVBASE_ROOT"
  echo
}

# Brief: Bootstrap gum TUI tool for interactive setup
# Uses: get_deb_arch, get_rpm_arch, show_progress, verify_checksum_value (functions)
# Returns: 0 if gum is available or installed, 1 otherwise
# Side-effects: Downloads and installs gum if missing
# Note: This runs before most libs are loaded to ensure UI is available;
# it intentionally duplicates some download/arch logic from install-custom.sh.
# The libs are not yet sourced at bootstrap time.
bootstrap_gum() {
  # Skip in non-interactive mode - gum not needed
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    return 0
  fi

  # Already installed - nothing to do
  if command -v gum &>/dev/null; then
    local current_version
    current_version=$(gum --version 2>/dev/null | head -1 | awk '{print $3}')
    show_progress success "gum available (${current_version})"
    return 0
  fi

  show_progress step "Installing gum for interactive setup..."

  # Version and architecture
  local version="0.17.0" # renovate: datasource=github-releases depName=charmbracelet/gum
  local arch
  arch=$(get_deb_arch) || {
    show_progress warning "Could not find TUI component gum (unsupported architecture: $(uname -m)), using whiptail as backup"
    return 1
  }

  # Detect package format based on environment
  local pkg_format="deb"
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora) pkg_format="rpm" ;;
  esac

  # For rpm, architecture naming differs
  local rpm_arch="$arch"
  if [[ "$pkg_format" == "rpm" ]]; then
    rpm_arch=$(get_rpm_arch)
  fi

  local package_name
  local gum_url
  if [[ "$pkg_format" == "deb" ]]; then
    package_name="gum_${version}_${arch}.deb"
  else
    package_name="gum-${version}.${rpm_arch}.rpm"
  fi
  gum_url="https://github.com/charmbracelet/gum/releases/download/v${version}/${package_name}"
  local checksums_url="https://github.com/charmbracelet/gum/releases/download/v${version}/checksums.txt"

  # Create temp directory if not set
  local temp_dir="${_DEVBASE_TEMP:-$(mktemp -d)}"
  local gum_pkg="${temp_dir}/${package_name}"

  # Check cache first (support both DEB and RPM cache paths)
  local cache_dir="${DEVBASE_DEB_CACHE:-}"
  if [[ -n "$cache_dir" ]] && [[ -f "${cache_dir}/${package_name}" ]]; then
    show_progress info "Using cached gum package"
    cp "${cache_dir}/${package_name}" "$gum_pkg"
  else
    # Download gum
    if ! curl -fL --progress-bar "$gum_url" -o "$gum_pkg" 2>/dev/null; then
      show_progress warning "Could not find TUI component gum (download failed), using whiptail as backup"
      return 1
    fi

    # Fetch and verify checksum using shared verification logic
    local expected_checksum=""
    if expected_checksum=$(get_checksum_from_manifest "$checksums_url" "$package_name" "30"); then
      if ! verify_checksum_value "$gum_pkg" "$expected_checksum"; then
        show_progress warning "Could not find TUI component gum (checksum failed), using whiptail as backup"
        return 1
      fi
    else
      show_progress warning "Could not verify gum checksum - continuing anyway"
    fi

    # Cache for future use
    if [[ -n "$cache_dir" ]]; then
      mkdir -p "$cache_dir"
      cp "$gum_pkg" "${cache_dir}/${package_name}"
    fi
  fi

  # Install gum based on package format
  if [[ -f "$gum_pkg" ]]; then
    if [[ "$pkg_format" == "deb" ]]; then
      if sudo dpkg -i "$gum_pkg" >/dev/null 2>&1; then
        show_progress success "gum installed (${version})"
        return 0
      else
        # Try to fix dependencies
        sudo apt-get install -f -y -q >/dev/null 2>&1 || true
        if command -v gum &>/dev/null; then
          show_progress success "gum installed (${version})"
          return 0
        fi
      fi
    else
      # RPM installation (try dnf, then rpm directly)
      if sudo dnf install -y "$gum_pkg" >/dev/null 2>&1 ||
        sudo rpm -i "$gum_pkg" >/dev/null 2>&1; then
        show_progress success "gum installed (${version})"
        return 0
      fi
    fi
  fi

  show_progress warning "Could not find TUI component gum, could not install, using whiptail as backup"
  return 1
}

# Brief: Determine which TUI mode to use and bootstrap if needed
# Uses: DEVBASE_TUI_MODE, NON_INTERACTIVE, bootstrap_gum (globals/functions)
# Returns: 0 on success, 1 on failure
# Sets DEVBASE_TUI_MODE to: "gum", "whiptail" (or "none" for NON_INTERACTIVE)
# Respects --tui=<mode> flag if set by parse_arguments()
select_tui_mode() {
  # Non-interactive doesn't need TUI
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    export DEVBASE_TUI_MODE="none"
    return 0
  fi

  # Handle explicit --tui=whiptail request (no fallback)
  if [[ "${DEVBASE_TUI_MODE}" == "whiptail" ]]; then
    if command -v whiptail &>/dev/null; then
      export DEVBASE_TUI_MODE="whiptail"
      return 0
    else
      printf "Error: whiptail requested but not installed.\n" >&2
      case "${_DEVBASE_ENV:-ubuntu}" in
      fedora)
        printf "Install with: sudo dnf install newt\n" >&2
        ;;
      *)
        printf "Install with: sudo apt-get install whiptail\n" >&2
        ;;
      esac
      return 1
    fi
  fi

  # Handle --tui=gum (default) - try gum, fall back to whiptail
  if [[ "${DEVBASE_TUI_MODE}" == "gum" ]]; then
    if command -v gum &>/dev/null || bootstrap_gum; then
      export DEVBASE_TUI_MODE="gum"
      return 0
    fi

    # Gum failed - fall back to whiptail
    if command -v whiptail &>/dev/null; then
      show_progress info "Using whiptail as TUI (gum not available)"
      export DEVBASE_TUI_MODE="whiptail"
      return 0
    fi
  fi

  # Neither available - return with helpful message
  printf "\n"
  printf "Error: No TUI component available.\n" >&2
  printf "\n" >&2
  printf "devbase requires either 'gum' or 'whiptail' for the interactive installer.\n" >&2
  printf "\n" >&2
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora)
    printf "Install whiptail with:\n" >&2
    printf "  sudo dnf install newt\n" >&2
    ;;
  *)
    printf "Install whiptail with:\n" >&2
    printf "  sudo apt-get install whiptail\n" >&2
    ;;
  esac
  printf "\n" >&2
  printf "Then run this script again.\n" >&2
  return 1
}
