#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

commit_msg_file="$1"

if ! command -v conform >/dev/null 2>&1; then
  echo -e "${CYAN}•${NC} conform not found, skipping commit message validation" >&2
  exit 0
fi

echo "→ Validating commit message..."

# Find repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  echo -e "${CYAN}•${NC} Not in a git repository" >&2
  exit 0
fi

cd "$repo_root" || exit 1

# Check for conform config in repo root
if [[ ! -f ".conform.yaml" ]]; then
  echo -e "${CYAN}•${NC} No .conform.yaml found in repo, skipping validation" >&2
  exit 0
fi

# Capture conform output
output=$(conform enforce --commit-msg-file="$commit_msg_file" 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  echo -e "${GREEN}✓${NC} Commit message valid"
  exit 0
else
  # Failure - show detailed output
  echo -e "${RED}✗${NC} Commit message validation failed" >&2
  echo "$output" >&2
  echo "   Check .conform.yaml for requirements" >&2
  exit 1
fi
