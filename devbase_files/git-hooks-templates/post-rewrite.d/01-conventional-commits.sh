#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

# Amend is already covered by post-commit. During rebase, that hook defers to us.
[[ ${1:-} == rebase ]] || exit 0
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" || exit 0

commits=()
while read -r old new _extra; do
  # Git supplies object IDs, not arbitrary revision expressions or shell text.
  # Accept either repository object format without assuming a hash length.
  if [[ ! $old =~ ^[0-9a-f]+$ || ! $new =~ ^[0-9a-f]+$ ]]; then
    printf '⚠ Invalid post-rewrite commit mapping; validation incomplete (non-blocking)\n' >&2
    exit 0
  fi
  # A squash maps several old commits to one new commit. Validate it only once.
  case " ${commits[*]} " in
  *" $new "*) ;;
  *) commits+=("$new") ;;
  esac
done
[[ ${#commits[@]} -gt 0 ]] || exit 0

script_dir="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)" || exit 0
# shellcheck source=../commit-validation.sh
source "$script_dir/../commit-validation.sh"
devbase_validate_commits "${commits[@]}"
