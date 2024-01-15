#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v hadolint >/dev/null 2>&1 || { echo -e "  ${CYAN}•${NC} hadolint not found, skipping" >&2; exit 0; }

echo "  → Checking Dockerfiles/Containerfiles..."
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '(Dockerfile|Containerfile|\.dockerfile|\.containerfile)' || true)

[[ -z "$files" ]] && { echo -e "  ${CYAN}ⓘ${NC} No Dockerfiles/Containerfiles staged"; exit 0; }

if echo "$files" | xargs -r hadolint; then
  echo -e "  ${GREEN}✓${NC} Hadolint passed"
else
  echo -e "  ${RED}✗${NC} Hadolint failed" >&2
  exit 1
fi
