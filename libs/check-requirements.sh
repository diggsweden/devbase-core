#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# Brief: Read OS information from /etc/os-release into global array
# Params: None
# Modifies: _DEVBASE_OS_INFO (global associative array)
# Returns: 0 always
# Side-effects: Sources /etc/os-release if it exists
get_os_info() {
  declare -gA _DEVBASE_OS_INFO

  if [[ -f /etc/os-release ]]; then
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

# Brief: Check if running under Windows Subsystem for Linux
# Params: None
# Uses: WSL_DISTRO_NAME, WSL_INTEROP (environment variables)
# Returns: 0 if WSL, 1 if not WSL
# Side-effects: Reads /proc/sys/fs/binfmt_misc/WSLInterop and /proc/version
is_wsl() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]]; then
    return 0
  fi

  if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    return 0
  fi

  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    return 0
  fi

  return 1
}

# Brief: Get WSL version if running on WSL
# Params: None
# Returns: Echoes WSL version (e.g. "2.6.0") or empty string if not WSL or cannot determine
# Side-effects: Calls wsl.exe on Windows to get version
get_wsl_version() {
  if ! is_wsl; then
    echo ""
    return 0
  fi

  # Try to get WSL version from wsl.exe --version
  if [[ -x /mnt/c/Windows/System32/wsl.exe ]]; then
    local wsl_version_output
    wsl_version_output=$(/mnt/c/Windows/System32/wsl.exe --version 2>/dev/null | grep "WSL version:" | head -1 | awk '{print $3}' | tr -d '\r')
    if [[ -n "$wsl_version_output" ]]; then
      echo "$wsl_version_output"
      return 0
    fi
  fi

  # Fallback: check kernel for WSL2 vs WSL1
  local kernel_version
  kernel_version=$(uname -r 2>/dev/null || echo "")

  if [[ "$kernel_version" =~ WSL2|microsoft-standard-WSL2 ]]; then
    echo "2.0.0" # Unknown WSL2 version, assume 2.0.0
    return 0
  fi

  # If on WSL but no WSL2 indicators, assume WSL1
  echo "1.0.0"
  return 0
}

# Brief: Check if running on Ubuntu Linux
# Params: None
# Uses: get_os_type (function)
# Returns: 0 if Ubuntu, 1 if not Ubuntu
is_ubuntu() {
  [[ "$(get_os_type)" == "ubuntu" ]]
  return 0
}

# Brief: Display OS and environment information to user
# Params: None
# Uses: get_os_info, is_wsl, DEVBASE_FROM_GIT, USER, HOME (globals)
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

  if [[ "${DEVBASE_FROM_GIT:-}" == "true" ]]; then
    printf "  • Installation: Git repository\n"
  elif [[ "${DEVBASE_FROM_GIT:-}" == "false" ]]; then
    printf "  • Installation: Archive/ZIP\n"
  fi

  printf "  • User: %s\n" "$USER"
  printf "  • Home: %s\n" "$HOME"
  return 0
}

# Brief: Check that required system tools are installed
# Params: None
# Uses: die (from utils)
# Returns: 0 if all tools present, exits via die if missing
check_required_tools() {
  local required_tools=(apt-get git snap sudo curl)
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

# Brief: Detect OS type and set environment variables
# Params: None
# Uses: get_os_type, is_wsl, show_progress, FORCE_DEVBASE_ENV (globals)
# Modifies: _DEVBASE_ENV (exported)
# Returns: 0 always
# Side-effects: Prints warning if not Ubuntu, prints newline
detect_environment() {
  local os_type
  os_type=$(get_os_type)

  if [[ "$os_type" != "ubuntu" ]]; then
    show_progress warning "This script is designed for Ubuntu. Detected: ${os_type}"
  fi

  if is_wsl; then
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
        printf "\n"
        die "WSL version too old. Please upgrade to WSL 2.6.0 or higher and try again."
      fi
    fi
  else
    export _DEVBASE_ENV="ubuntu"
  fi

  if [[ -n "${FORCE_DEVBASE_ENV:-}" ]]; then
    export _DEVBASE_ENV="$FORCE_DEVBASE_ENV"
    show_progress info "Environment overridden to: ${_DEVBASE_ENV}"
  fi

  printf "\n"
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
      show_progress "done" "Ubuntu version $current_version ✓"
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
    printf "Disk space may be insufficient, continue anyway? (y/N): "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] || exit 1
  else
    show_progress "done" "Disk space: ${available_gb}GB available ✓"
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

  if [[ -n "${_DEVBASE_ENV:-}" ]]; then
    case "${_DEVBASE_ENV}" in
    ubuntu | wsl-ubuntu) ;;
    *) invalid_vars+=("_DEVBASE_ENV=${_DEVBASE_ENV} (must be 'ubuntu' or 'wsl-ubuntu')") ;;
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

  show_progress "done" "Home directory paths ✓"
  return 0
}

# PRE-FLIGHT CHECK
run_preflight_checks() {
  show_progress info "Running pre-flight checks..."

  check_ubuntu_version "24.04" || return 1

  check_disk_space 5 || return 1

  check_path_writable || return 1

  printf "%b Please enter your password when prompted\n" "${DEVBASE_COLORS[DIM]}ℹ"
  if ! sudo -v; then
    show_progress error "sudo access required"
    return 1
  fi

  show_progress success "Pre-flight checks complete"
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
export -f is_wsl
export -f get_wsl_version
export -f is_ubuntu
export -f display_os_info
export -f check_required_tools
export -f check_critical_tools
export -f detect_environment
export -f check_ubuntu_version
export -f validate_required_vars
export -f run_preflight_checks
