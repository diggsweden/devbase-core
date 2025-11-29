#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# DevBase Verification Library
# Shared functions for base and custom verification scripts

# Color Constants
readonly NC='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;90m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'

# Icons
readonly CHECK="✓"
readonly CROSS="✗"
readonly WARN="‼"
readonly INFO="ⓘ"

# Output formatting constants
readonly MAX_VALUE_LENGTH=60
readonly MAX_PATH_LENGTH=50
readonly BOX_WIDTH_NARROW=54
readonly BOX_WIDTH_WIDE=110
readonly MAX_PROXY_DISPLAY_LENGTH=50
readonly MAX_REGISTRY_DISPLAY_LENGTH=80

# Counters (exported so custom scripts can update them)
export TOTAL_CHECKS=0
export PASSED_CHECKS=0
export FAILED_CHECKS=0
export WARNING_CHECKS=0

# Arrays to track failed and warning messages
declare -a FAILED_MESSAGES=()
declare -a WARNING_MESSAGES=()

has_command() {
  command -v "$1" &>/dev/null
}

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

trim() {
  echo "$1" | xargs
}

home_to_tilde() {
  echo "${1/#$HOME/~}"
}

file_exists() {
  [[ -f "$1" ]] 2>/dev/null
}

dir_exists() {
  [[ -d "$1" ]] 2>/dev/null
}

normalize_path() {
  echo "${1/#$HOME/\~}"
}

truncate_string() {
  local str="$1"
  local max_len="${2:-$MAX_VALUE_LENGTH}"

  if [[ ${#str} -gt $max_len ]]; then
    echo "${str:0:$((max_len - 3))}..."
  else
    echo "$str"
  fi
}

# Helper function to repeat a character N times for headers/borders
# Usage: repeat_char '=' 50
repeat_char() {
  local char="$1"
  local count="$2"
  printf "${char}%.0s" $(seq 1 "$count")
}

print_header() {
  printf "\n%b%s%b\n" "${BOLD}${BLUE}" "$1" "${NC}"
  printf "%b%s%b\n" "${BLUE}" "$(repeat_char '=' 50)" "${NC}"
}

print_subheader() {
  local subheader="$1"
  printf "\n  %b%s:%b\n" "${BOLD}" "$subheader" "${NC}"
}

print_check() {
  local status="$1"
  local message="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  case "$status" in
  pass)
    printf "  %b%s%b %s\n" "${GREEN}" "$CHECK" "${NC}" "$message"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    ;;
  fail)
    printf "  %b%s%b %s\n" "${RED}" "$CROSS" "${NC}" "$message"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    FAILED_MESSAGES+=("$message")
    ;;
  warn)
    printf "  %b%s%b %s\n" "${YELLOW}" "$WARN" "${NC}" "$message"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    WARNING_MESSAGES+=("$message")
    ;;
  info)
    printf "  %b%s%b %s\n" "${CYAN}" "$INFO" "${NC}" "$message"
    ;;
  esac
}

check_file_content() {
  local file="$1"
  local pattern="$2"
  local pass_msg="$3"
  local fail_msg="${4:-$pass_msg not found}"
  local check_type="${5:-pass}"

  if ! file_exists "$file"; then
    local display_path=$(home_to_tilde "$file")
    if [[ "$check_type" == "pass" ]]; then
      print_check "fail" "$fail_msg (file missing: $display_path)"
    else
      print_check "$check_type" "$fail_msg"
    fi
    return 1
  fi

  if grep -q "$pattern" "$file" 2>/dev/null; then
    print_check "pass" "$pass_msg"
  else
    print_check "warn" "$fail_msg"
  fi
  return 0
}

# Mask credentials in proxy URLs: http://user:pass@host -> http://***:***@host
mask_url_credentials() {
  sed 's/:[^@]*@/:****@/'
}

check_env_var() {
  local var_name="$1"
  local max_length="${2:-60}"
  local mask_password="${3:-false}"

  if [[ -n "${!var_name:-}" ]]; then
    local value="${!var_name}"

    # Mask password in URLs if requested (e.g., proxy URLs with credentials)
    if [[ "$mask_password" == "true" ]] && [[ "$value" =~ ://.*:.*@ ]]; then
      value=$(echo "$value" | mask_url_credentials)
    fi

    # Replace home directory with ~ for readability
    value="${value/#$HOME/~}"

    # Truncate long values with ellipsis
    if [[ ${#value} -gt $max_length ]]; then
      value="${value:0:$((max_length - 3))}..."
    fi

    printf "  %b%s%b %s = %s\n" "${GREEN}" "$CHECK" "${NC}" "$var_name" "$value"
    return 0
  else
    return 1
  fi
}

display_file_box() {
  local file="$1"
  local width="${2:-$BOX_WIDTH_NARROW}"
  local skip_pattern="${3:-^[[:space:]]*#}"
  local mask_tokens="${4:-false}"
  local preserve_indent="${5:-false}"

  local term_width=$(tput cols 2>/dev/null || echo 80)
  local min_width=40
  local max_box_width=$((term_width - 8))

  if [[ $max_box_width -lt $min_width ]]; then
    while IFS= read -r line; do
      if [[ -n "$line" ]] && [[ ! "$line" =~ $skip_pattern ]]; then
        local display_line="$line"
        if [[ "$mask_tokens" == "true" ]] && [[ "$line" =~ TOKEN ]]; then
          display_line=$(echo "$line" | sed "s/=.*/='**********'/")
        fi
        if [[ "$preserve_indent" != "true" ]]; then
          display_line=$(echo "$display_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        fi
        if [[ -n "$(echo "$display_line" | tr -d '[:space:]')" ]]; then
          printf "    %s\n" "$display_line"
        fi
      fi
    done <"$file"
    return
  fi

  if [[ $width -gt $max_box_width ]]; then
    width=$max_box_width
  fi

  local border_length=$((width + 2))
  local border=$(repeat_char '─' $border_length)

  printf "  %b┌%s┐%b\n" "${DIM}" "$border" "${NC}"

  while IFS= read -r line; do
    if [[ -n "$line" ]] && [[ ! "$line" =~ $skip_pattern ]]; then
      local display_line="$line"

      # Mask sensitive tokens (e.g., GITHUB_TOKEN=...)
      if [[ "$mask_tokens" == "true" ]] && [[ "$line" =~ TOKEN ]]; then
        display_line=$(echo "$line" | sed "s/=.*/='**********'/")
      fi

      # Always mask passwords in proxy URLs (e.g., http://user:pass@host)
      if [[ "$display_line" =~ ://.*:.*@ ]]; then
        display_line=$(echo "$display_line" | mask_url_credentials)
      fi

      # Trim whitespace: leading and trailing, or just trailing
      if [[ "$preserve_indent" == "true" ]]; then
        # Only trim trailing whitespace
        display_line=$(echo "$display_line" | sed 's/[[:space:]]*$//')
      else
        # Trim both leading and trailing whitespace
        display_line=$(echo "$display_line" |
          sed 's/^[[:space:]]*//' | # Remove leading spaces
          sed 's/[[:space:]]*$//')  # Remove trailing spaces
      fi

      if [[ -n "$(echo "$display_line" | tr -d '[:space:]')" ]]; then
        if [[ ${#display_line} -gt $width ]]; then
          display_line="${display_line:0:$((width - 3))}..."
        fi

        printf "  %b│ %-*s │%b\n" "${DIM}" "$width" "$display_line" "${NC}"
      fi
    fi
  done <"$file"

  printf "  %b└%s┘%b\n" "${DIM}" "$border" "${NC}"
}

check_npm_proxy() {
  # NPM proxy and registry are already checked in "Development Language Settings"
  # HTTP_PROXY is checked in "Proxy Configuration"
  # NPM_CONFIG_REGISTRY is checked in "Development Language Settings"
  # This function kept for backwards compatibility but does nothing
  return 0
}

check_git_proxy() {
  local git_proxy=$(git config --global http.proxy 2>/dev/null || echo "")
  if [[ -n "$git_proxy" ]]; then
    # Mask password in proxy URL (http://user:pass@host -> http://***:***@host)
    git_proxy=$(echo "$git_proxy" | mask_url_credentials)
    print_check "pass" "Git proxy configured: ${git_proxy:0:$MAX_PROXY_DISPLAY_LENGTH}"
  else
    print_check "warn" "Git proxy not configured"
  fi
}

check_snap_proxy() {
  if command -v snap &>/dev/null; then
    local snap_http_proxy=$(sudo -n snap get system proxy.http 2>/dev/null || echo "")
    local snap_https_proxy=$(sudo -n snap get system proxy.https 2>/dev/null || echo "")

    if [[ -n "$snap_http_proxy" ]] && [[ -n "$snap_https_proxy" ]]; then
      # Mask password in proxy URL (http://user:pass@host -> http://***:***@host)
      snap_http_proxy=$(echo "$snap_http_proxy" | mask_url_credentials)
      print_check "pass" "Snap proxy configured: ${snap_http_proxy:0:$MAX_PROXY_DISPLAY_LENGTH}"
    else
      print_check "warn" "Snap proxy not configured (refresh sudo: sudo -v)"
    fi
  fi
}

check_maven_proxy() {
  local maven_settings="$HOME/.m2/settings.xml"
  ! file_exists "$maven_settings" && return 0

  if grep -q "<proxy>" "$maven_settings" 2>/dev/null; then
    print_check "pass" "Maven proxy configured (~/.m2/settings.xml)"
    display_file_box "$maven_settings" "$BOX_WIDTH_WIDE" "^[[:space:]]*\<\!--\|^[[:space:]]*--\>"
  else
    print_check "info" "Maven settings exists but no proxy configured"
  fi
}

check_gradle_proxy() {
  local gradle_properties="$HOME/.gradle/gradle.properties"
  ! file_exists "$gradle_properties" && return 0

  if grep -q "systemProp.http" "$gradle_properties" 2>/dev/null; then
    print_check "pass" "Gradle proxy configured (~/.gradle/gradle.properties)"
    display_file_box "$gradle_properties" "$BOX_WIDTH_WIDE"
  else
    print_check "info" "Gradle properties exists but no proxy configured"
  fi
}

export -f has_command
export -f trim
export -f home_to_tilde
export -f file_exists
export -f dir_exists
export -f normalize_path
export -f truncate_string
export -f print_header
export -f print_subheader
export -f print_check
export -f check_file_content
export -f check_env_var
export -f display_file_box
export -f check_npm_proxy
export -f check_git_proxy
export -f check_snap_proxy
export -f check_maven_proxy
export -f check_gradle_proxy
