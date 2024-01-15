#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_markdown() {
  print_header "MARKDOWN LINTING (RUMDL)"

  if ! command -v rumdl >/dev/null 2>&1; then
    print_error "rumdl not found. Install with: mise install"
    return 1
  fi

  if rumdl check . 2>/dev/null; then
    print_success "Markdown linting passed"
    return 0
  else
    print_error "Markdown linting failed - run 'just lint-markdown-fix' to fix"
    return 1
  fi
}

fix_markdown() {
  print_header "FIXING MARKDOWN (RUMDL)"

  if ! command -v rumdl >/dev/null 2>&1; then
    print_error "rumdl not found. Install with: mise install"
    return 1
  fi

  if rumdl check --fix . 2>/dev/null; then
    print_success "Markdown files fixed"
    return 0
  else
    print_error "Failed to fix markdown files"
    return 1
  fi
}

ACTION="${1:-check}"

case "$ACTION" in
check)
  check_markdown
  ;;
fix)
  fix_markdown
  ;;
*)
  print_error "Unknown action: $ACTION"
  echo "Usage: $0 [check|fix]"
  exit 1
  ;;
esac
