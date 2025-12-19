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

remote="$1"
url="$2"

if ! command -v git >/dev/null 2>&1; then
  printf "%b•%b git not found\n" "${RED}" "${NC}" >&2
  exit 1
fi

printf "→ Verifying commit signatures (GPG/SSH)...\n"

# Read stdin to get the list of commits being pushed
while read -r local_ref local_sha remote_ref remote_sha; do
  if [[ "$local_sha" == "0000000000000000000000000000000000000000" ]]; then
    # Deleting a branch, skip
    continue
  fi

  if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
    # New branch - find merge base with default branch to avoid checking all history
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    merge_base=$(git merge-base "origin/$default_branch" "$local_sha" 2>/dev/null || echo "")

    if [[ -n "$merge_base" ]]; then
      # Check only commits since divergence from default branch
      range="$merge_base..$local_sha"
    else
      # Fallback: check all commits in the branch
      range="$local_sha"
    fi
  else
    # Existing branch, check commits between remote and local
    range="$remote_sha..$local_sha"
  fi

  # Get list of commits in range
  commits=$(git rev-list "$range" 2>/dev/null || echo "")

  if [[ -z "$commits" ]]; then
    continue
  fi

  # Verify each commit has a valid signature (GPG or SSH)
  # %G? returns: G (good), B (bad), U (untrusted), X (expired), Y (good + expired), R (revoked), E (no key), N (no signature)
  failed=0
  while IFS= read -r commit; do
    sig_status=$(git log -1 --format="%G?" "$commit" 2>/dev/null)

    # Accept only "G" (good signature - works for both GPG and SSH)
    if [[ "$sig_status" != "G" ]]; then
      # Provide status-specific error messages
      case "$sig_status" in
      U) status_msg="untrusted signature - add key to ~/.config/ssh/allowed_signers or GPG trustdb" ;;
      B) status_msg="bad signature - signature verification failed" ;;
      N) status_msg="not signed" ;;
      E) status_msg="cannot verify - signing key not found" ;;
      X) status_msg="good signature but key has expired" ;;
      Y) status_msg="good signature but expired key was valid at signing time" ;;
      R) status_msg="good signature but key has been revoked" ;;
      *) status_msg="unknown signature status: $sig_status" ;;
      esac
      printf "%b✗%b Commit %s %s\n" "${RED}" "${NC}" "$commit" "$status_msg" >&2
      failed=1
    fi
  done <<<"$commits"

  if [[ $failed -eq 1 ]]; then
    printf "%b✗%b Some commits lack valid signatures\n" "${RED}" "${NC}" >&2
    printf "   Ensure commits are signed:\n" >&2
    printf "     GPG: git commit -S\n" >&2
    printf "     SSH: git config gpg.format ssh && git commit -S\n" >&2
    printf "   Or configure automatic signing: git config commit.gpgsign true\n" >&2
    exit 1
  fi
done

printf "%b✓%b All commits have valid signatures\n" "${GREEN}" "${NC}"
exit 0
