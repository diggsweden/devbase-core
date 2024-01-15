#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_yaml() {
  print_header "YAML LINTING (YAMLFMT)"

  if ! command -v yamlfmt >/dev/null 2>&1; then
    print_error "yamlfmt not found. Install with: mise install"
    return 1
  fi

  if yamlfmt -lint . 2>/dev/null; then
    print_success "YAML linting passed"
    return 0
  else
    print_error "YAML linting failed - run 'just lint-yaml-fix' to fix"
    return 1
  fi
}

# Fix YAML formatting
fix_yaml() {
  print_header "FIXING YAML (YAMLFMT)"

  if ! command -v yamlfmt >/dev/null 2>&1; then
    print_error "yamlfmt not found. Install with: mise install"
    return 1
  fi

  if yamlfmt . 2>/dev/null; then
    print_success "YAML files formatted"
    return 0
  else
    print_error "Failed to format YAML files"
    return 1
  fi
}

ACTION="${1:-check}"

case "$ACTION" in
check)
  check_yaml
  ;;
fix)
  fix_yaml
  ;;
*)
  print_error "Unknown action: $ACTION"
  echo "Usage: $0 [check|fix]"
  exit 1
  ;;
esac
