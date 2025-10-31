#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

command -v gitleaks >/dev/null 2>&1 || { echo -e "  ${CYAN}•${NC} gitleaks not found, skipping" >&2; exit 0; }

echo "  → Scanning staged files for secrets..."
if gitleaks protect --staged --verbose --redact=50 2>&1; then
  echo -e "  ${GREEN}✓${NC} No secrets detected"
else
  echo -e "  ${RED}✗${NC} Secret detected! Commit blocked." >&2
  echo "     Fix the issue or use 'git commit --no-verify' to bypass" >&2
  exit 1
fi
