#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_shell_scripts() {
  print_header "SHELL SCRIPT LINTING (SHELLCHECK)"

  if ! command -v shellcheck >/dev/null 2>&1; then
    print_error "shellcheck not found. Install with: mise install"
    return 1
  fi

  # Find all shell scripts excluding certain directories
  local scripts=$(find . -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "./dot/*" -not -path "./.git/*" 2>/dev/null)

  if [ -z "$scripts" ]; then
    print_warning "No shell scripts found to check"
    return 0
  fi

  # Exclude warnings that don't affect functionality:
  # SC1091: Not following sourced files (expected when sourcing external libs)
  # SC2034: unused variables (often used in other sourced scripts)
  # SC2155: declare and assign separately (style preference, not a bug)
  if echo "$scripts" | xargs -r shellcheck --severity=info --exclude=SC1091,SC2034,SC2155 2>/dev/null; then
    print_success "Shell script linting passed"
    return 0
  else
    print_error "Shell script linting failed"
    return 1
  fi
}

check_shell_scripts
