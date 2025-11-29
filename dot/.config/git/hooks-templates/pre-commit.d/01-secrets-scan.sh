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

command -v gitleaks >/dev/null 2>&1 || {
  printf "%b•%b gitleaks not found, skipping\n" "${CYAN}" "${NC}" >&2
  exit 0
}

printf "→ Scanning staged files for secrets (gitleaks)...\n"

# Capture gitleaks output
output=$(gitleaks protect --staged --verbose --redact=50 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  printf "%b✓%b No secrets detected\n" "${GREEN}" "${NC}"
  exit 0
else
  # Failure - show full gitleaks output
  printf "%b✗%b Secret detected! Commit blocked.\n" "${RED}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  printf "   Fix the issue or use 'git commit --no-verify' to bypass\n" >&2
  exit 1
fi
