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

# Unicode symbols
export CHECK='✓'
export CROSS='✗'
export WARN='⚠'
export INFO='ℹ'
export ARROW='→'

# Helper functions for colored output
print_header() {
  printf "\n${YELLOW}************ $1 ***********${NC}\n\n"
}

print_success() {
  printf "${GREEN}${CHECK} $1${NC}\n"
}

print_error() {
  printf "${RED}${CROSS} $1${NC}\n" >&2
}

print_warning() {
  printf "${YELLOW}${WARN} $1${NC}\n" >&2
}

print_info() {
  printf "${CYAN}${INFO} $1${NC}\n"
}

print_arrow() {
  printf "${BLUE}${ARROW} $1${NC}\n"
}
