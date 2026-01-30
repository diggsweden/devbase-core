#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Post-commit validation using conform
# Validates the commit after it's created (non-blocking)
# This allows conform to check signatures which are only available post-commit

set -uo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if ! command -v conform >/dev/null 2>&1; then
  printf "%b•%b conform not found, skipping commit validation\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

# Find repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  exit 0
fi

cd "$repo_root" || exit 0

# Check for conform config in repo root
if [[ ! -f ".conform.yaml" ]]; then
  printf "%b•%b No .conform.yaml found in repo, skipping validation\n" "${CYAN}" "${NC}" >&2
  exit 0
fi

printf "→ Validating commit (conform)...\n"

# Validate the HEAD commit (includes message, signature, etc.)
output=$(conform enforce --commit-ref=HEAD 2>&1)
status=$?

if [[ $status -eq 0 ]]; then
  printf "%b✓%b Commit validated\n" "${GREEN}" "${NC}"
else
  # Warning only - post-commit cannot block
  printf "%b⚠%b Commit validation issues (non-blocking):\n" "${YELLOW}" "${NC}" >&2
  printf "%s\n" "$output" >&2
  printf "   See .conform.yaml for requirements\n" >&2
fi

# Always exit 0 - post-commit hooks should not fail
exit 0
