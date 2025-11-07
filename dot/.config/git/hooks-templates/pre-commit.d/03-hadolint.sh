#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v hadolint >/dev/null 2>&1 || { echo -e "  ${CYAN}•${NC} hadolint not found, skipping" >&2; exit 0; }

echo "  → Checking Dockerfiles/Containerfiles (hadolint)..."
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '(Dockerfile|Containerfile|\.dockerfile|\.containerfile)' || true)

[[ -z "$files" ]] && { echo -e "  ${CYAN}ⓘ${NC} No Dockerfiles/Containerfiles staged"; exit 0; }

# Capture hadolint output
output=$(echo "$files" | xargs -r hadolint 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  echo -e "  ${GREEN}✓${NC} Hadolint passed"
  exit 0
else
  # Failure - show full hadolint output
  echo -e "  ${RED}✗${NC} Hadolint failed" >&2
  echo "$output" >&2
  exit 1
fi
