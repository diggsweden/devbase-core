#!/usr/bin/env bash
set -uo pipefail

commit_msg_file="$1"

branch_name="$(git rev-parse --abbrev-ref HEAD)"

# Auto-detect issue pattern from branch: PREFIX-123
# Supports: JIRA-123, PROJ-456, ABC-789, GH-123, etc.
if [[ "$branch_name" =~ ([A-Z]{2,10})-([0-9]+) ]]; then
  issue="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
  footer="Refs: ${issue}"

  # Skip if footer already exists
  if grep -q "^Refs:" "$commit_msg_file"; then
    exit 0
  fi

  # Insert before first 'Signed-off-by:' or other trailers if present
  if grep -q "^Signed-off-by:" "$commit_msg_file"; then
    sed -i "0,/^Signed-off-by:/s/^Signed-off-by:/${footer}\nSigned-off-by:/" "$commit_msg_file"
    exit 0
  fi

  # Otherwise append footer
  printf "\n%s\n" "$footer" >>"$commit_msg_file"
else
  CYAN='\033[0;36m'
  NC='\033[0m'
  echo -e "  ${CYAN}ⓘ${NC} No issue number detected in branch name, skipping" >&2
fi
