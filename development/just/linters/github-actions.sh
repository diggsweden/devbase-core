#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_github_actions() {
  print_header "GITHUB ACTIONS LINTING (ACTIONLINT)"

  if [ ! -d .github/workflows ]; then
    print_warning "No GitHub Actions workflows found, skipping"
    return 0
  fi

  if ! command -v actionlint >/dev/null 2>&1; then
    print_error "actionlint not found. Install with: mise install"
    return 1
  fi

  if actionlint 2>/dev/null; then
    print_success "GitHub Actions linting passed"
    return 0
  else
    print_error "GitHub Actions linting failed"
    return 1
  fi
}

check_github_actions
