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

echo "  → Verifying GPG signatures (git verify-commit)..."

# Read stdin to get the list of commits being pushed
while read -r local_ref local_sha remote_ref remote_sha; do
  if [[ "$local_sha" == "0000000000000000000000000000000000000000" ]]; then
    # Deleting a branch, skip
    continue
  fi

  if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
    # New branch, check all commits
    range="$local_sha"
  else
    # Existing branch, check commits between remote and local
    range="$remote_sha..$local_sha"
  fi

  # Get list of commits in range
  commits=$(git rev-list "$range" 2>/dev/null || echo "")
  
  if [[ -z "$commits" ]]; then
    continue
  fi

  # Verify each commit has a valid GPG signature
  failed=0
  while IFS= read -r commit; do
    if ! git verify-commit "$commit" >/dev/null 2>&1; then
      echo -e "  ${RED}✗${NC} Commit $commit is not signed or has invalid signature" >&2
      failed=1
    fi
  done <<< "$commits"

  if [[ $failed -eq 1 ]]; then
    echo -e "  ${RED}✗${NC} Some commits lack valid GPG signatures" >&2
    echo "     Ensure commits are signed: git commit -S" >&2
    echo "     Or configure automatic signing: git config commit.gpgsign true" >&2
    exit 1
  fi
done

echo -e "  ${GREEN}✓${NC} All commits have valid GPG signatures"
exit 0
