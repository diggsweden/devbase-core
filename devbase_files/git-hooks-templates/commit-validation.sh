#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Shared advisory validation of committed objects, including their signatures.
# Sourced from the installed hooks directory, never from the worktree.
devbase_validate_commits() {
  local ref commit output status
  local failed=0

  if ! command -v gommitlint >/dev/null 2>&1; then
    printf '• gommitlint not found, skipping commit validation\n' >&2
    return 0
  fi

  printf '→ Validating %s commit(s) (gommitlint)...\n' "$#"
  for ref in "$@"; do
    if ! commit=$(git rev-parse --verify --end-of-options "${ref}^{commit}" 2>/dev/null); then
      printf '⚠ Cannot resolve commit %s for validation (non-blocking)\n' "$ref" >&2
      failed=$((failed + 1))
      continue
    fi

    # Pass the exact object, not a moving HEAD or a range that could miss root
    # commits. stdin belongs to the hook protocol, not to the validator.
    output=$(gommitlint validate -v --ref "$commit" </dev/null 2>&1)
    status=$?
    if [[ $status -ne 0 ]]; then
      failed=$((failed + 1))
      printf '⚠ Commit validation issues for %s (non-blocking):\n%s\n' "$commit" "$output" >&2
    fi
  done

  if [[ $failed -eq 0 ]]; then
    printf '✓ %s commit(s) validated\n' "$#"
  else
    printf '⚠ %s of %s commit(s) could not pass validation (non-blocking)\n' "$failed" "$#" >&2
  fi
  # Post-commit and post-rewrite cannot undo an operation; CI enforces policy.
  return 0
}
