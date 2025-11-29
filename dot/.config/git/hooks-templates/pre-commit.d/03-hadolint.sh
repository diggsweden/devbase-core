#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v hadolint >/dev/null 2>&1 || {
  printf "%b•%b hadolint not found, skipping\n" "${CYAN}" "${NC}" >&2
  exit 0
}

printf "→ Checking Dockerfiles/Containerfiles (hadolint)...\n"
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '(Dockerfile|Containerfile|\.dockerfile|\.containerfile)' || true)

[[ -z "$files" ]] && {
  printf "%bⓘ%b No Dockerfiles/Containerfiles staged\n" "${CYAN}" "${NC}"
  exit 0
}

# Capture hadolint output
output=$(printf "%s" "$files" | xargs -r hadolint 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  # Success - only show simple message
  printf "%b✓%b Hadolint passed\n" "${GREEN}" "${NC}"
  exit 0
else
  # Failure - show full hadolint output
  printf "%b✗%b Hadolint failed\n" "${RED}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  exit 1
fi
