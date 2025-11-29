#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

commit_msg_file="$1"

if ! command -v conform >/dev/null 2>&1; then
  printf "%b•%b conform not found, skipping commit message validation\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

printf "→ Validating commit message...\n"

# Find repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  printf "%b•%b Not in a git repository\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

cd "$repo_root" || exit 1

# Check for conform config in repo root
if [[ ! -f ".conform.yaml" ]]; then
  printf "%b•%b No .conform.yaml found in repo, skipping validation\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

# Capture conform output
output=$(conform enforce --commit-msg-file="$commit_msg_file" 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  printf "%b✓%b Commit message valid\n" "${GREEN}" "${NC}"
  exit 0
else
  # Failure - show detailed output
  printf "%b✗%b Commit message validation failed\n" "${RED}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  printf "   Check .conform.yaml for requirements\n" >&2
  exit 1
fi
