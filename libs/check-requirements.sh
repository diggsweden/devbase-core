#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Read OS information from /etc/os-release into global array
# Params: None
# Modifies: _DEVBASE_OS_INFO (global associative array)
# Returns: 0 always
# Side-effects: Sources /etc/os-release if it exists
get_os_info() {
  declare -gA _DEVBASE_OS_INFO

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091 # System file, always exists on Linux
    source /etc/os-release
    _DEVBASE_OS_INFO[id]="${ID:-unknown}"
    _DEVBASE_OS_INFO[name]="${NAME:-Unknown}"
    _DEVBASE_OS_INFO[version]="${VERSION:-}"
    _DEVBASE_OS_INFO[version_id]="${VERSION_ID:-unknown}"
  else
    _DEVBASE_OS_INFO[id]="unknown"
    _DEVBASE_OS_INFO[name]="Unknown"
    _DEVBASE_OS_INFO[version]=""
    _DEVBASE_OS_INFO[version_id]="unknown"
  fi

  return 0
}

# Brief: Get OS type identifier (e.g., "ubuntu", "debian")
# Params: None
# Uses: get_os_info, _DEVBASE_OS_INFO (globals)
# Returns: Echoes OS ID to stdout, returns 0
get_os_type() {
  get_os_info
  printf "%s\n" "${_DEVBASE_OS_INFO[id]}"
  return 0
}

# Brief: Get OS version ID (e.g., "24.04", "22.04")
# Params: None
# Uses: get_os_info, _DEVBASE_OS_INFO (globals)
# Returns: Echoes version ID to stdout, returns 0
get_os_version() {
  get_os_info
  printf "%s\n" "${_DEVBASE_OS_INFO[version_id]}"
  return 0
}

# Brief: Get OS full name (e.g., "Ubuntu")
# Params: None
# Uses: get_os_info, _DEVBASE_OS_INFO (globals)
# Returns: Echoes OS name to stdout, returns 0
get_os_name() {
  get_os_info
  printf "%s\n" "${_DEVBASE_OS_INFO[name]}"
  return 0
}

# Brief: Get OS full version string (e.g., "24.04 LTS (Noble Numbat)")
# Params: None
# Uses: get_os_info, _DEVBASE_OS_INFO (globals)
# Returns: Echoes full version to stdout, returns 0
get_os_version_full() {
  get_os_info
  printf "%s\n" "${_DEVBASE_OS_INFO[version]}"
  return 0
}

# is_wsl() is defined in distro.sh - source it if not already available
if ! declare -f is_wsl &>/dev/null; then
  source "${DEVBASE_LIBS:-${DEVBASE_ROOT}/libs}/distro.sh"
fi

# Brief: Get WSL version if running on WSL
# Params: None
# Returns: Echoes WSL version (e.g. "2.6.0") or empty string if not WSL or cannot determine
# Side-effects: Calls wsl.exe on Windows to get version
get_wsl_version() {
  if ! is_wsl; then
    echo ""
    return 0
  fi

  # Get WSL version from wsl.exe --version (use full path)
  if [[ ! -x /mnt/c/Windows/System32/wsl.exe ]]; then
    echo ""
    return 1
  fi

  local wsl_version_output
  wsl_version_output=$(/mnt/c/Windows/System32/wsl.exe --version 2>/dev/null | grep "WSL version:" | head -1 | awk '{print $3}' | tr -d '\r')

  if [[ -z "$wsl_version_output" ]]; then
    echo ""
    return 1
  fi

  # Convert "2.6.1.0" to "2.6.1" (strip build number)
  wsl_version_output=$(echo "$wsl_version_output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
  echo "$wsl_version_output"
  return 0
}

# Brief: Check if running on Ubuntu Linux
# Params: None
# Uses: get_os_type (function)
# Returns: 0 if Ubuntu, 1 if not Ubuntu
is_ubuntu() {
  [[ "$(get_os_type)" == "ubuntu" ]]
}

# Brief: Display OS and environment information to user
# Params: None
# Uses: get_os_info, is_wsl, _DEVBASE_FROM_GIT, USER, HOME (globals)
# Returns: 0 always
# Side-effects: Prints OS info to stdout
display_os_info() {
  get_os_info
  local os_name="${_DEVBASE_OS_INFO[name]}"
  local os_version="${_DEVBASE_OS_INFO[version]}"

  printf "  • OS: %s %s\n" "$os_name" "$os_version"

  if is_wsl; then
    printf "  • Environment: WSL\n"
  else
    printf "  • Environment: Native Linux\n"
  fi

  if [[ "${_DEVBASE_FROM_GIT}" == "true" ]]; then
    printf "  • Installation: Git repository\n"
  elif [[ "${_DEVBASE_FROM_GIT}" == "false" ]]; then
    printf "  • Installation: Archive/ZIP\n"
  fi

  printf "  • User: %s\n" "$USER"
  printf "  • Home: %s\n" "$HOME"
  return 0
}

# Brief: Check that required system tools are installed
# Params: None
# Uses: die, _DEVBASE_ENV (from utils)
# Returns: 0 if all tools present, exits via die if missing
check_required_tools() {
  # Core tools required on all distros
  local required_tools=(git sudo curl)

  # Add distro-specific package manager
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora)
    required_tools+=(dnf)
    ;;
  ubuntu | wsl-ubuntu | *)
    required_tools+=(apt-get)
    # Snap not required on WSL
    if [[ "${_DEVBASE_ENV:-}" != "wsl-ubuntu" ]]; then
      required_tools+=(snap)
    fi
    ;;
  esac

  local missing_tools=()

  for cmd in "${required_tools[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_tools+=("$cmd")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing_tools[*]}"
  fi

  return 0
}

# Brief: Warn about Nerd Font requirement on WSL
# Params: None
# Uses: show_progress (function)
# Returns: 0 always (warning only)
# Side-effects: Displays Nerd Font warning and installation instructions
_check_wsl_nerd_font_prereq() {
  tui_blank_line
  show_progress warning "WSL: Nerd Font needed (install on Windows side)"
  show_progress info "If you see strange chars (boxes/?), install a Nerd Font on Windows"
  tui_blank_line

  return 0
}

# Brief: Detect OS type and set environment variables
# Params: None
# Uses: get_os_type, is_wsl, show_progress (globals)
# Modifies: _DEVBASE_ENV (exported)
# Returns: 0 always
# Side-effects: Prints warning if unsupported distro, prints newline
detect_environment() {
  # get_distro() is defined in distro.sh (sourced in load_devbase_libraries)
  local distro
  distro=$(get_distro)

  case "$distro" in
  ubuntu)
    export _DEVBASE_ENV="ubuntu"
    ;;
  ubuntu-wsl)
    export _DEVBASE_ENV="wsl-ubuntu"

    # Check WSL version and require >= 2.6.0
    local wsl_version
    wsl_version=$(get_wsl_version)

    if [[ -n "$wsl_version" ]]; then
      local major minor
      major=$(echo "$wsl_version" | cut -d. -f1)
      minor=$(echo "$wsl_version" | cut -d. -f2)

      if [[ "$major" -lt 2 ]] || { [[ "$major" -eq 2 ]] && [[ "$minor" -lt 6 ]]; }; then
        show_progress error "WSL version $wsl_version detected - version 2.6.0 or higher is required"
        show_progress info "To upgrade WSL, run in Windows PowerShell:"
        show_progress info "  wsl --update"
        show_progress info "Then restart your WSL distribution"
        show_progress info "See: https://learn.microsoft.com/en-us/windows/wsl/install"
        tui_blank_line
        die "WSL version too old. Please upgrade to WSL 2.6.0 or higher and try again."
      fi
    fi

    # Check for Nerd Font prerequisite on WSL
    _check_wsl_nerd_font_prereq
    ;;
  fedora)
    export _DEVBASE_ENV="fedora"
    ;;
  *)
    show_progress warning "Unsupported distribution: ${distro}. Proceeding with best effort."
    export _DEVBASE_ENV="$distro"
    ;;
  esac

  tui_blank_line
  return 0
}

# Brief: Verify Ubuntu version meets minimum requirement
# Params: $1 - minimum version (optional, default: "24.04")
# Uses: is_ubuntu, get_os_version, show_progress (functions)
# Returns: 0 on success, 1 if not Ubuntu
# Side-effects: Prints version check results
check_ubuntu_version() {
  local min_version=${1:-"24.04"}
  local current_version=""

  if ! is_ubuntu; then
    show_progress error "This script requires Ubuntu Linux"
    return 1
  fi

  current_version=$(get_os_version)

  if ! command -v dpkg &>/dev/null; then
    show_progress warning "Cannot verify Ubuntu version (dpkg not found)"
    return 0
  fi

  if [[ "$current_version" != "unknown" ]]; then
    if dpkg --compare-versions "$current_version" "lt" "$min_version" 2>/dev/null; then
      show_progress warning "Ubuntu $min_version or later recommended (found: $current_version)"
    else
      show_progress success "Ubuntu version $current_version"
    fi
  else
    show_progress warning "Cannot determine Ubuntu version"
  fi

  return 0
}

# Brief: Check available disk space in home directory
# Params: $1 - required GB (optional, default: 5)
# Uses: HOME, show_progress (globals)
# Returns: 0 if sufficient or user confirms, 1 via exit if user declines
# Side-effects: Prompts user if space insufficient, reads stdin
check_disk_space() {
  local required_gb=${1:-5}
  local available_gb

  available_gb=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')

  if [[ "$available_gb" -lt "$required_gb" ]]; then
    show_progress warning "Low disk space: ${available_gb}GB available, ${required_gb}GB recommended"
    if ! ask_yes_no "Disk space may be insufficient, continue anyway?" "N"; then
      exit 1
    fi
  else
    show_progress success "Disk space: ${available_gb}GB available"
  fi
  return 0
}
# Brief: Validate that required environment variables are set and valid
# Params: None
# Uses: DEVBASE_ENV, _DEVBASE_ENV, show_progress (globals)
# Returns: 0 if valid, 1 if missing or invalid
# Side-effects: Prints error messages for invalid variables
validate_required_vars() {
  local required_vars=(
    'DEVBASE_ENV'
  )

  local missing_vars=()
  local invalid_vars=()

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("$var")
    fi
  done

  if [[ -n "${_DEVBASE_ENV}" ]]; then
    case "${_DEVBASE_ENV}" in
    ubuntu | wsl-ubuntu | fedora) ;;
    *) invalid_vars+=("_DEVBASE_ENV=${_DEVBASE_ENV} (must be 'ubuntu', 'wsl-ubuntu', or 'fedora')") ;;
    esac
  fi

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    show_progress error "Missing required variables:"
    for var in "${missing_vars[@]}"; do
      show_progress error "  - $var"
    done
    return 1
  fi

  if [[ ${#invalid_vars[@]} -gt 0 ]]; then
    show_progress error "Invalid variable values:"
    for msg in "${invalid_vars[@]}"; do
      show_progress error "  - $msg"
    done
    return 1
  fi

  return 0
}

# Brief: Verify XDG directories exist and are writable
# Params: None
# Uses: XDG_BIN_HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME, show_progress (globals)
# Returns: 0 if all paths writable, 1 if any path fails
# Side-effects: Creates directories if needed, prints success message
check_path_writable() {
  local paths=(
    "$XDG_BIN_HOME"
    "$XDG_CONFIG_HOME"
    "$XDG_CACHE_HOME"
  )

  for path in "${paths[@]}"; do
    if [[ ! -d "$path" ]]; then
      mkdir -p "$path" 2>/dev/null || {
        show_progress error "Cannot create $path"
        return 1
      }
    fi

    if [[ ! -w "$path" ]]; then
      show_progress error "Not writable: $path"
      return 1
    fi
  done

  show_progress success "Home directory paths"
  return 0
}

# Brief: Check if MISE_GITHUB_TOKEN is set to avoid GitHub API rate limiting
# Params: None
# Uses: MISE_GITHUB_TOKEN, NON_INTERACTIVE, show_progress (globals)
# Returns: 0 if token set or user continues, 1 if user declines to continue
# Side-effects: Prompts user if token not set (unless NON_INTERACTIVE), reads stdin
check_mise_github_token() {
  if [[ -n "${MISE_GITHUB_TOKEN}" ]]; then
    show_progress success "GitHub token (MISE_GITHUB_TOKEN) configured"
    return 0
  fi

  show_progress warning "MISE_GITHUB_TOKEN not set"
  show_progress info "Without this token, mise downloads MAY be rate limited or stalled"
  show_progress info "See: https://mise.jdx.dev/configuration.html#mise_github_token"

  # In non-interactive mode, just warn and continue
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    show_progress info "Continuing in non-interactive mode (token recommended but not required)"
    return 0
  fi

  # Display instructions and prompt using TUI-appropriate formatting
  if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]] && command -v gum &>/dev/null; then
    echo
    gum style --foreground 240 \
      "To set the token:" \
      "" \
      "1. Create a GitHub personal access token at:" \
      "   https://github.com/settings/tokens/new?scopes=public_repo" \
      "" \
      "2. Export it before running setup:" \
      "   export MISE_GITHUB_TOKEN=ghp_your_token_here" \
      "" \
      "3. Or add it to your shell config permanently"
    echo
    if ask_yes_no "Continue without GitHub token?" "N"; then
      show_progress info "Continuing without GitHub token (may experience rate limiting)"
      return 0
    else
      show_progress info "Installation cancelled - please set MISE_GITHUB_TOKEN and try again"
      exit 1
    fi
  elif [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    local message="MISE_GITHUB_TOKEN is not set.

Without this token, mise downloads MAY be rate limited or stalled.

To set the token:

1. Create a GitHub personal access token at:
   https://github.com/settings/tokens/new?scopes=public_repo

2. Export it before running setup:
   export MISE_GITHUB_TOKEN=ghp_your_token_here

3. Or add it to your shell config permanently"

    if whiptail --backtitle "$WT_BACKTITLE" --title "GitHub Token Not Set" \
      --yes-button "Continue" --no-button "Cancel" \
      --yesno "$message\n\nDo you want to continue without GitHub token?$WT_NAV_HINTS" "$WT_HEIGHT_XLARGE" "$WT_WIDTH"; then
      show_progress info "Continuing without GitHub token (may experience rate limiting)"
      return 0
    else
      show_progress info "Installation cancelled - please set MISE_GITHUB_TOKEN and try again"
      exit 1
    fi
  else
    printf "\n"
    printf "To set the token, you can:\n"
    printf "  1. Create a GitHub personal access token at:\n"
    printf "     https://github.com/settings/tokens/new?scopes=public_repo\n"
    printf "  2. Export it before running setup:\n"
    printf "     export MISE_GITHUB_TOKEN=ghp_your_token_here\n"
    printf "  3. Or add it to your shell config permanently\n"
    printf "\n"
    if ask_yes_no "Continue without GitHub token?" "N"; then
      show_progress info "Continuing without GitHub token (may experience rate limiting)"
      return 0
    else
      show_progress info "Installation cancelled - please set MISE_GITHUB_TOKEN and try again"
      exit 1
    fi
  fi
}

# Brief: Get Secure Boot mode without printing
# Params: None
# Uses: is_wsl, mokutil
# Returns: Prints mode to stdout: "disabled", "user", "setup", "audit", "deployed", "unknown", "wsl"
# Side-effects: None
get_secure_boot_mode() {
  # Skip check on WSL - not applicable
  if is_wsl; then
    echo "wsl"
    return 0
  fi

  # Check if mokutil is available
  if ! command -v mokutil &>/dev/null; then
    echo "unknown"
    return 0
  fi

  # Check Secure Boot status
  local sb_state
  sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")

  # Determine mode
  if echo "$sb_state" | grep -qi "SecureBoot enabled"; then
    if echo "$sb_state" | grep -qi "Deployed Mode"; then
      echo "deployed"
    else
      echo "user"
    fi
  elif echo "$sb_state" | grep -qi "Setup Mode"; then
    echo "setup"
  elif echo "$sb_state" | grep -qi "Audit Mode"; then
    echo "audit"
  elif echo "$sb_state" | grep -qi "User Mode"; then
    echo "user"
  else
    echo "disabled"
  fi
}

# Brief: Check if Secure Boot is enabled on native Linux
# Params: None
# Uses: is_wsl, show_progress (globals)
# Returns: 0 if enabled (User/Setup/Audit Mode) or not applicable, 1 if disabled
# Side-effects: Prints warning if Secure Boot is disabled
check_secure_boot() {
  local mode
  mode=$(get_secure_boot_mode)

  case "$mode" in
  wsl | unknown | user | deployed)
    return 0
    ;;
  setup)
    show_progress warning "Secure Boot is in Setup Mode (key provisioning state)"
    show_progress warning "Unsigned kernel modules can load now but will be blocked after enrolling keys"
    show_progress warning "Sign modules or disable Secure Boot before exiting Setup Mode"
    return 0
    ;;
  audit)
    show_progress warning "Secure Boot is in Audit Mode (logging violations only, not blocking)"
    show_progress warning "Unsigned kernel modules currently allowed but violations are logged"
    show_progress warning "Sign modules or disable Secure Boot before transitioning to User Mode"
    return 0
    ;;
  disabled)
    return 1
    ;;
  *)
    return 0
    ;;
  esac
}

# Brief: Check Fedora version meets minimum requirement
# Params: $1 - minimum version (optional, default: "40")
# Uses: get_os_version, show_progress (functions)
# Returns: 0 on success
check_fedora_version() {
  local min_version=${1:-"40"}
  local current_version=""

  current_version=$(get_os_version)

  if [[ "$current_version" != "unknown" ]]; then
    if [[ "$current_version" -lt "$min_version" ]] 2>/dev/null; then
      show_progress warning "Fedora $min_version or later recommended (found: $current_version)"
    else
      show_progress success "Fedora version $current_version"
    fi
  else
    show_progress warning "Cannot determine Fedora version"
  fi

  return 0
}

# PRE-FLIGHT CHECK
run_preflight_checks() {
  show_progress step "Running pre-flight checks"

  # Collect results for whiptail summary
  local -a check_results=()

  # Distro-specific version check
  case "${_DEVBASE_ENV:-ubuntu}" in
  fedora)
    check_fedora_version "40" || return 1
    check_results+=("✓ Fedora version OK")
    ;;
  ubuntu | wsl-ubuntu | *)
    check_ubuntu_version "24.04" || return 1
    check_results+=("✓ Ubuntu version 24.04+")
    ;;
  esac

  check_disk_space 5 || return 1
  check_results+=("✓ Disk space OK")

  check_path_writable || return 1
  check_results+=("✓ Home directory writable")

  check_mise_github_token || return 1
  if [[ -n "${MISE_GITHUB_TOKEN:-}" ]]; then
    check_results+=("✓ MISE_GITHUB_TOKEN configured")
  else
    check_results+=("⚠ MISE_GITHUB_TOKEN not set (continuing anyway)")
  fi

  # Check sudo access early - especially important for whiptail mode
  # to avoid jumping to terminal mid-installation
  if ! sudo -n true 2>/dev/null; then
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
      whiptail --backtitle "$WT_BACKTITLE" --title "Sudo Access Required" \
        --msgbox "This installation requires sudo (administrator) access.\n\nAfter pressing OK, you will be prompted to enter your password.$WT_NAV_HINTS" "$WT_HEIGHT_SMALL" "$WT_WIDTH"
      # Clear screen for password prompt - unavoidable terminal visibility
      clear
    else
      show_progress info "Sudo access required for installation"
    fi

    if ! sudo -v; then
      show_progress error "Sudo access denied"
      return 1
    fi

    # Immediately show infobox after sudo to hide terminal
    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
      _wt_infobox "Installing" "Sudo access granted. Continuing..."
    fi
    check_results+=("✓ Sudo access granted")
  else
    check_results+=("✓ Sudo access available")
  fi

  show_progress success "Pre-flight checks complete"

  # In whiptail mode, show summary before continuing to user configuration
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
    local summary="Pre-flight checks completed successfully:\n\n"
    for result in "${check_results[@]}"; do
      summary+="  $result\n"
    done
    summary+="\nPress OK to continue with configuration..."

    whiptail --backtitle "$WT_BACKTITLE" --title "Pre-flight Checks" \
      --msgbox "$summary$WT_NAV_HINTS" "$WT_HEIGHT_LARGE" "$WT_WIDTH"
  fi

  return 0
}

# Brief: Check that critical Unix tools are available
# Params: None
# Uses: show_progress (from ui-helpers)
# Returns: 0 if all tools present, 1 if any missing
check_critical_tools() {
  local critical_tools=(bash grep sed awk curl git)
  local missing_tools=()

  for tool in "${critical_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    show_progress error "Critical tools missing: ${missing_tools[*]}"
    return 1
  fi

  return 0
}

export -f get_os_info
export -f get_os_type
export -f get_os_version
export -f get_os_name
export -f get_os_version_full
export -f get_wsl_version
export -f is_ubuntu
export -f display_os_info
export -f check_required_tools
export -f check_critical_tools
export -f detect_environment
export -f check_ubuntu_version
export -f validate_required_vars
export -f check_mise_github_token
export -f get_secure_boot_mode
export -f check_secure_boot
export -f run_preflight_checks
