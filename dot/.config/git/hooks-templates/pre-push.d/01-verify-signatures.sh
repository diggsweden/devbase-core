#!/usr/bin/env bash
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

remote="$1"
url="$2"

if ! command -v git >/dev/null 2>&1; then
  echo -e "  ${RED}•${NC} git not found" >&2
  exit 1
fi

echo "  → Verifying commit signatures (GPG/SSH)..."

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
      echo -e "  ${RED}✗${NC} Commit $commit is not signed or has invalid signature (status: $sig_status)" >&2
      failed=1
    fi
  done <<< "$commits"

  if [[ $failed -eq 1 ]]; then
    echo -e "  ${RED}✗${NC} Some commits lack valid signatures" >&2
    echo "     Ensure commits are signed:" >&2
    echo "       GPG: git commit -S" >&2
    echo "       SSH: git config gpg.format ssh && git commit -S" >&2
    echo "     Or configure automatic signing: git config commit.gpgsign true" >&2
    exit 1
  fi
done

echo -e "  ${GREEN}✓${NC} All commits have valid signatures"
exit 0
