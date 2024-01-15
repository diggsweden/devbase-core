#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/colors.sh"

declare -A status=(
  [markdown]="PASS"
  [yaml]="PASS"
  [actions]="PASS"
  [secrets]="PASS"
  [shell]="PASS"
  [shell - fmt]="PASS"
  [commit]="PASS"
)
overall_status="PASS"

run_check() {
  local script="$1"
  local check_name="$2"
  shift 2

  if "${SCRIPT_DIR}/linters/${script}" "$@"; then
    status[$check_name]="PASS"
  else
    status[$check_name]="FAIL"
    overall_status="FAIL"
  fi
  printf "\n"
}

main() {
  printf "\n${BLUE}Starting code quality checks...${NC}\n"
  printf "=====================================\n\n"

  # Run all checks
  run_check "markdown.sh" "markdown" "check"
  run_check "yaml.sh" "yaml" "check"

  # GitHub Actions might skip
  if "${SCRIPT_DIR}/linters/github-actions.sh"; then
    status[actions]="PASS"
  elif [ ! -d .github/workflows ]; then
    status[actions]="SKIP"
  else
    status[actions]="FAIL"
    overall_status="FAIL"
  fi
  printf "\n"

  run_check "secrets.sh" "secrets"
  run_check "shell.sh" "shell"
  run_check "shell-fmt.sh" "shell-fmt" "check"

  # Commits might skip
  if "${SCRIPT_DIR}/linters/commits.sh"; then
    status[commit]="PASS"
  else
    local current_branch=$(git branch --show-current)
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@" || echo "main")
    if [ "$(git rev-list --count ${default_branch}.. 2>/dev/null || echo 0)" = "0" ]; then
      status[commit]="SKIP"
    else
      status[commit]="FAIL"
      overall_status="FAIL"
    fi
  fi
  printf "\n"

  printf "${YELLOW}=====================================\n"
  printf "       CODE QUALITY SUMMARY\n"
  printf "=====================================${NC}\n\n"

  # Print status for each check
  for check in markdown yaml actions secrets; do
    local display_name="${check^}"
    if [ "${status[$check]}" = "PASS" ]; then
      printf "${GREEN}✓ ${display_name}${NC}  "
    elif [ "${status[$check]}" = "SKIP" ]; then
      printf "${YELLOW}○ ${display_name}${NC}  "
    else
      printf "${RED}✗ ${display_name}${NC}  "
    fi
  done
  printf "\n"

  for check in shell shell-fmt commit; do
    local display_name="${check^}"
    display_name="${display_name//-fmt/ Format}" # Replace -fmt with Format
    if [ "${status[$check]}" = "PASS" ]; then
      printf "${GREEN}✓ ${display_name}${NC}  "
    elif [ "${status[$check]}" = "SKIP" ]; then
      printf "${YELLOW}○ ${display_name} (no new)${NC}  "
    else
      printf "${RED}✗ ${display_name}${NC}  "
    fi
  done
  printf "\n\n"

  if [ "$overall_status" = "PASS" ]; then
    printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "     ✓ ALL CHECKS PASSED!\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    exit 0
  else
    printf "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "     ✗ SOME CHECKS FAILED\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n${YELLOW}Run ${GREEN}just lint-fix${YELLOW} to auto-fix some issues${NC}\n"
    exit 1
  fi
}

main "$@"
