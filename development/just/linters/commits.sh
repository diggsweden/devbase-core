#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_commits() {
  print_header "COMMIT HEALTH (CONFORM)"

  if ! command -v conform >/dev/null 2>&1; then
    print_error "conform not found. Install with: mise install"
    return 1
  fi

  local current_branch=$(git branch --show-current)
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@" || echo "main")

  # Check if there are any commits to verify
  if [ "$(git rev-list --count "${default_branch}". . 2>/dev/null || echo 0)" = "0" ]; then
    print_info "No commits found in current branch: ${current_branch} (compared to ${default_branch})"
    return 0
  fi

  if conform enforce --base-branch="${default_branch}" 2>/dev/null; then
    print_success "Commit health check passed"
    return 0
  else
    print_error "Commit health check failed - check your commit messages"
    return 1
  fi
}

check_commits
