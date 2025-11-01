#!/usr/bin/env bash
set -uo pipefail

# Activate mise if available
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/colors.sh"

REQUIRED_TOOLS=(mise git just)
LINTING_TOOLS=(rumdl yamlfmt actionlint gitleaks shellcheck conform)

check_tool() {
  local tool=$1
  if command -v "$tool" >/dev/null 2>&1; then
    print_success "$tool"
    return 0
  else
    print_error "$tool"
    return 1
  fi
}

main() {
  printf "Checking required tools...\n"
  printf "=========================\n"

  local missing_tools=""
  local missing_count=0

  # Check core required tools
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! check_tool "$tool"; then
      missing_tools="$missing_tools $tool"
      ((missing_count++))
    fi
  done

  # Check linting tools
  for tool in "${LINTING_TOOLS[@]}"; do
    if ! check_tool "$tool"; then
      missing_tools="$missing_tools $tool"
      ((missing_count++))
    fi
  done

  printf "\n"

  if [ $missing_count -gt 0 ]; then
    print_error "Missing $missing_count tools!"
    printf "\n"
    print_info "To fix this:"
    printf "1. Activate mise in your shell:\n"
    printf "   ${GREEN}eval \"\$(mise activate bash)\"${NC}  # For bash\n"
    printf "   ${GREEN}eval \"\$(mise activate zsh)\"${NC}   # For zsh\n"
    printf "   ${GREEN}mise activate fish | source${NC}     # For fish\n"
    printf "2. Install tools: ${GREEN}mise install${NC}\n"
    printf "3. Restart your shell or source your rc file\n"
    printf "\nFor more details, see: ${BLUE}docs/guides/development.adoc${NC}\n"
    return 1
  else
    print_success "All required tools installed!"
    return 0
  fi
}

main "$@"
