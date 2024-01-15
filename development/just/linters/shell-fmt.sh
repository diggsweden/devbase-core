#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

MODE="${1:-check}"

format_shell_scripts() {
  print_header "SHELL SCRIPT FORMATTING (SHFMT)"

  if ! command -v shfmt >/dev/null 2>&1; then
    print_error "shfmt not found. Install with: mise install"
    return 1
  fi

  # Find all shell scripts excluding certain directories and problematic files
  # Exclude configure-theme.sh due to shfmt incorrectly formatting associative array keys
  local scripts=$(find . -type f \( -name "*.sh" -o -name "*.bash" \) \
    -not -path "./dot/*" \
    -not -path "./.git/*" \
    -not -path "./libs/configure-theme.sh" \
    2>/dev/null)

  if [ -z "$scripts" ]; then
    print_warning "No shell scripts found to format"
    return 0
  fi

  if [ "$MODE" == "fix" ]; then
    # Format in place with 2 spaces indentation
    if echo "$scripts" | xargs -r shfmt -i 2 -w 2>/dev/null; then
      print_success "Shell scripts formatted"
      return 0
    else
      print_error "Shell script formatting failed"
      return 1
    fi
  else
    # Check formatting only with 2 spaces indentation
    if echo "$scripts" | xargs -r shfmt -i 2 -d 2>/dev/null; then
      print_success "Shell script formatting check passed"
      return 0
    else
      print_error "Shell script formatting check failed (run 'just lint-shell-fmt-fix' to fix)"
      return 1
    fi
  fi
}

format_shell_scripts
