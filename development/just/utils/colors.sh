#!/usr/bin/env bash
# Color and symbol definitions for consistent output

# Terminal colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export GRAY='\033[0;90m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Unicode symbols (matching DevBase symbols)
export CHECK='✓'
export CROSS='✗'
export WARN='‼'
export INFO='ⓘ'
export ARROW='→'

# Helper functions for colored output
print_header() {
  printf "\n%b************ %s ***********%b\n\n" "${YELLOW}" "$1" "${NC}"
}

print_success() {
  printf "%b%b %s%b\n" "${GREEN}" "${CHECK}" "$1" "${NC}"
}

print_error() {
  printf "%b%b %s%b\n" "${RED}" "${CROSS}" "$1" "${NC}" >&2
}

print_warning() {
  printf "%b%b %s%b\n" "${YELLOW}" "${WARN}" "$1" "${NC}" >&2
}

print_info() {
  printf "%b%b %s%b\n" "${CYAN}" "${INFO}" "$1" "${NC}"
}

print_arrow() {
  printf "%b%b %s%b\n" "${BLUE}" "${ARROW}" "$1" "${NC}"
}
