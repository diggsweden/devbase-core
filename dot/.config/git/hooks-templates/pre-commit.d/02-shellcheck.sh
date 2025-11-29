#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v shellcheck >/dev/null 2>&1 || {
  printf "%b•%b shellcheck not found, skipping\n" "${CYAN}" "${NC}" >&2
  exit 0
}

printf "→ Checking shell scripts (shellcheck)...\n"
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(sh|bash)$' || true)

[[ -z "$files" ]] && {
  printf "%bⓘ%b No shell scripts staged\n" "${CYAN}" "${NC}"
  exit 0
}

# SC1091: Not following sourced files (expected when sourcing external libs)
# SC2034: Unused variables (intentional for constants/config)
# SC2155: Declare and assign separately (common pattern, low risk)
# Capture shellcheck output
output=$(printf "%s" "$files" | xargs -r shellcheck --severity=info --exclude=SC1091,SC2034,SC2155 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  printf "%b✓%b Shellcheck passed\n" "${GREEN}" "${NC}"
  exit 0
else
  # Failure - show full shellcheck output
  printf "%b✗%b Shellcheck failed\n" "${RED}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  exit 1
fi
