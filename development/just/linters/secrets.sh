#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_secrets() {
  print_header "SECRET SCANNING (GITLEAKS)"

  if ! command -v gitleaks >/dev/null 2>&1; then
    print_error "gitleaks not found. Install with: mise install"
    return 1
  fi

  # Determine which branch to compare against
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@" || echo "main")
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [ "$current_branch" = "$default_branch" ]; then
    printf "On default branch, scanning all commits...\n"
    if gitleaks detect --source=. --verbose --redact=50; then
      print_success "No secrets found"
      return 0
    else
      print_error "Secret scanning failed - secrets may be present!"
      return 1
    fi
  else
    printf "Scanning commits different from %s...\n" "$default_branch"
    if gitleaks detect --source=. --verbose --redact=50; then
      print_success "No secrets found"
      return 0
    else
      print_error "Secret scanning failed - secrets may be present!"
      return 1
    fi
  fi
}

check_secrets
