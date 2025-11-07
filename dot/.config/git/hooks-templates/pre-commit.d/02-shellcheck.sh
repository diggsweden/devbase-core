#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v shellcheck >/dev/null 2>&1 || { echo -e "${CYAN}•${NC} shellcheck not found, skipping" >&2; exit 0; }

echo "→ Checking shell scripts (shellcheck)..."
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(sh|bash)$' || true)

[[ -z "$files" ]] && { echo -e "${CYAN}ⓘ${NC} No shell scripts staged"; exit 0; }

# SC1091: Not following sourced files (expected when sourcing external libs)
# SC2034: Unused variables (intentional for constants/config)
# SC2155: Declare and assign separately (common pattern, low risk)
# Capture shellcheck output
output=$(echo "$files" | xargs -r shellcheck --severity=info --exclude=SC1091,SC2034,SC2155 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  echo -e "${GREEN}✓${NC} Shellcheck passed"
  exit 0
else
  # Failure - show full shellcheck output
  echo -e "${RED}✗${NC} Shellcheck failed" >&2
  echo "$output" >&2
  exit 1
fi
