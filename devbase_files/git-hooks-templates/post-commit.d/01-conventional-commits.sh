#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Post-commit validation using gommitlint
# Validates the commit after it's created (non-blocking)
# This allows signature validation after the commit object exists

set -uo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if ! command -v gommitlint >/dev/null 2>&1; then
  printf "%b•%b gommitlint not found, skipping commit validation\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

# Find repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  exit 0
fi

cd "$repo_root" || exit 0

printf "→ Validating commit (gommitlint)...\n"

# Validate the HEAD commit (includes message, signature, etc.)
output=$(gommitlint validate -v 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  printf "%b✓%b Commit validated\n" "${GREEN}" "${NC}"
else
  # Warning only - post-commit cannot block
  printf "%b⚠%b Commit validation issues (non-blocking):\n" "${YELLOW}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  printf "   Configure project-specific rules in .gommitlint.yaml if needed\n" >&2
fi

# Always exit 0 - post-commit hooks should not fail
exit 0
