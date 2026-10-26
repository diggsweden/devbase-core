#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Validate ordinary commits after creation, so signatures can be checked.
# Rebase commits are validated together by post-rewrite, after squashing.

set -uo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  exit 0
fi

cd "$repo_root" || exit 0

# Git resolves these per worktree; .git may be a file in a linked worktree.
for state in rebase-merge rebase-apply; do
  state_dir=$(git rev-parse --git-path "$state") || exit 0
  [[ -d "$state_dir" ]] && exit 0
done

script_dir="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)" || exit 0
# shellcheck source=../commit-validation.sh
source "$script_dir/../commit-validation.sh"
devbase_validate_commits HEAD

# Always exit 0 - post-commit hooks should not fail
exit 0
