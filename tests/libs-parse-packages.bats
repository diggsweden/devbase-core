#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2030,SC2031,SC2034,SC2153
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT

# Tests for libs/parse-packages.sh - unified package configuration parser

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  # Source check-requirements for is_wsl function
  source "${DEVBASE_ROOT}/libs/check-requirements.sh"
}

teardown() {
  common_teardown
}

# Helper to create test packages.yaml
create_test_packages() {
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  apt:
    curl: {}
    git: {}
    tlp: { tags: ["@skip-wsl"] }
  snap:
    chromium: {}
    ghostty: { options: "--classic", tags: ["@skip-wsl"] }
  mise:
    fzf: { backend: "aqua:junegunn/fzf", version: "v0.67.0" }
    jq: { version: "1.7" }
  custom:
    mise: { version: "v2025.1.0", installer: "install_mise" }
    lazyvim: { version: "abc123", installer: "install_lazyvim", tags: ["@optional"] }
  vscode:
    redhat.vscode-yaml: { version: "1.17.0" }
    optional.ext: { version: "1.0.0", tags: ["@optional"] }

packs:
  java:
    description: "Java development"
    apt:
      default-jdk: {}
    mise:
      java: { version: "temurin-21" }
      maven: { version: "3.9.6" }
    custom:
      intellij: { version: "2024.1", installer: "install_intellij", tags: ["@optional"] }
    vscode:
      redhat.java: { version: "1.30.0" }
  
  node:
    description: "Node.js development"
    mise:
      node: { version: "20.10.0" }
    vscode:
      vue.volar: { version: "2.0.0" }
  
  python:
    description: "Python development"
    apt:
      python3: {}
      python3-venv: {}
    mise:
      python: { version: "3.12.0" }
EOF
}

# =============================================================================
# yq requirement check
# =============================================================================

@test "parse-packages.sh fails with error when yq not available" {
  local bash_path temp_bin
  bash_path=$(command -v bash)

  temp_bin="${TEST_DIR}/bin"
  mkdir -p "$temp_bin"
  ln -sf "$bash_path" "$temp_bin/bash"

  run env PATH="$temp_bin" bash -c 'source "'"${DEVBASE_LIBS}"'/parse-packages.sh" 2>&1'

  assert_failure
  assert_output --partial "yq is required"
}

# =============================================================================
# _get_merged_packages tests
# =============================================================================

@test "_get_merged_packages returns base yaml when no custom overlay" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  local result
  result=$(_get_merged_packages)
  
  [[ "$result" == *"curl:"* ]]
  [[ "$result" == *"fzf:"* ]]
}

@test "_get_merged_packages merges custom overlay" {
  create_test_packages
  
  # Create custom overlay
  cat > "${TEST_DIR}/packages-custom.yaml" <<'EOF'
core:
  apt:
    custom-tool: {}
  mise:
    fzf: { backend: "aqua:junegunn/fzf", version: "v0.99.0" }
packs:
  company:
    description: "Company tools"
    apt:
      internal-pkg: {}
EOF
  
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/packages-custom.yaml"
  export SELECTED_PACKS=""
  # Clear cache
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  local result
  result=$(_get_merged_packages)
  
  # Should have base packages
  [[ "$result" == *"curl:"* ]]
  # Should have custom package added
  [[ "$result" == *"custom-tool:"* ]]
  # Should have new pack
  [[ "$result" == *"company:"* ]]
  # Should have overridden version
  [[ "$result" == *"v0.99.0"* ]]
}

@test "_get_merged_packages caches result" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  # First call
  _get_merged_packages > /dev/null
  
  # Cache should be populated
  [[ -n "$_MERGED_YAML" ]]
}

# =============================================================================
# get_apt_packages tests
# =============================================================================

@test "get_apt_packages returns core packages" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_apt_packages
  
  assert_success
  assert_line "curl"
  assert_line "git"
}

@test "get_apt_packages includes selected pack packages" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java python"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_apt_packages
  
  assert_success
  assert_line "default-jdk"
  assert_line "python3"
  assert_line "python3-venv"
}

@test "get_apt_packages excludes unselected pack packages" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="node"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_apt_packages
  
  assert_success
  refute_line "default-jdk"
  refute_line "python3"
}

@test "get_apt_packages skips @skip-wsl packages in WSL" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  export WSL_DISTRO_NAME="Ubuntu"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_apt_packages
  
  assert_success
  assert_line "curl"
  refute_line "tlp"
  
  unset WSL_DISTRO_NAME
}

@test "get_apt_packages includes @skip-wsl packages outside WSL" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  unset WSL_DISTRO_NAME WSL_INTEROP
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  # shellcheck disable=SC2329
  is_wsl() { return 1; }
  export -f is_wsl
  
  run get_apt_packages
  
  assert_success
  assert_line "tlp"
}

# =============================================================================
# get_snap_packages tests
# =============================================================================

@test "get_snap_packages returns package|options format" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  unset WSL_DISTRO_NAME WSL_INTEROP
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  # shellcheck disable=SC2329
  is_wsl() { return 1; }
  export -f is_wsl
  
  run get_snap_packages
  
  assert_success
  assert_line "chromium|"
  assert_line "ghostty|--classic"
}

@test "get_snap_packages respects @skip-wsl tag" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  export WSL_DISTRO_NAME="Ubuntu"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_snap_packages
  
  assert_success
  assert_line "chromium|"
  refute_line --partial "ghostty"
  
  unset WSL_DISTRO_NAME
}

# =============================================================================
# get_mise_packages tests
# =============================================================================

@test "get_mise_packages returns tool_key|version format" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_mise_packages
  
  assert_success
  assert_line "aqua:junegunn/fzf|v0.67.0"
  assert_line "jq|1.7"
}

@test "get_mise_packages includes pack tools" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java node"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_mise_packages
  
  assert_success
  assert_line "java|temurin-21"
  assert_line "maven|3.9.6"
  assert_line "node|20.10.0"
}

@test "get_mise_packages handles gitlab backend" {
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  mise:
    glab: { backend: "gitlab:gitlab-org/cli", version: "v1.0.0" }
packs: {}
EOF

  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"

  run get_mise_packages

  assert_success
  assert_line "gitlab:gitlab-org/cli|v1.0.0"
}

# =============================================================================
# get_custom_packages tests
# =============================================================================

@test "get_custom_packages returns tool|version|installer|tags format" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_custom_packages
  
  assert_success
  assert_line 'mise|v2025.1.0|install_mise|'
  assert_line --partial 'lazyvim|abc123|install_lazyvim|'
}

@test "get_custom_packages includes pack custom tools" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_custom_packages
  
  assert_success
  assert_line --partial "intellij|2024.1|install_intellij"
}

# =============================================================================
# get_vscode_packages tests
# =============================================================================

@test "get_vscode_packages returns extension|version|tags format" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_vscode_packages
  
  assert_success
  assert_line "redhat.vscode-yaml|1.17.0|"
}

@test "get_vscode_packages includes pack extensions" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java node"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_vscode_packages
  
  assert_success
  assert_line "redhat.java|1.30.0|"
  assert_line "vue.volar|2.0.0|"
}

# =============================================================================
# get_available_packs tests
# =============================================================================

@test "get_available_packs returns pack|description format" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_available_packs
  
  assert_success
  assert_line "java|Java development"
  assert_line "node|Node.js development"
  assert_line "python|Python development"
}

@test "get_available_packs includes custom packs from overlay" {
  create_test_packages
  cat > "${TEST_DIR}/packages-custom.yaml" <<'EOF'
packs:
  company:
    description: "Internal tools"
    apt:
      company-cli: {}
EOF
  
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/packages-custom.yaml"
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_available_packs
  
  assert_success
  assert_line "company|Internal tools"
}

# =============================================================================
# get_pack_contents tests
# =============================================================================

@test "get_pack_contents returns list of pack items" {
  command -v apt-get &>/dev/null || skip "apt not available"
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="apt"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_pack_contents "java"
  
  assert_success
  # java pack shows mise tools and custom tools
  assert_line "java"
  assert_line "maven"
  assert_line "intellij"
  # vscode extensions shown with label
  assert_line "redhat.java (VS Code)"
  # apt packages are summarized, not listed individually
  assert_line "+ 1 system packages"
}

@test "get_pack_contents returns empty for pack with no items" {
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  empty:
    description: "Empty pack"
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_pack_contents "empty"
  
  assert_success
  assert_output ""
}

@test "get_pack_contents shows primary tools and labels vscode extensions" {
  command -v apt-get &>/dev/null || skip "apt not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  test:
    description: "Test pack"
    apt:
      pkg1: {}
      pkg2: {}
    mise:
      tool1: {version: "1.0"}
    vscode:
      ext1: {version: "1.0"}
      ext2: {version: "2.0"}
    custom:
      myapp: {version: "1.0", installer: "install_myapp"}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="apt"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_pack_contents "test"
  
  assert_success
  # Primary tools are shown
  assert_line "tool1"
  assert_line "myapp"
  # VS Code extensions shown with label
  assert_line "ext1 (VS Code)"
  assert_line "ext2 (VS Code)"
  # apt packages are summarized with count
  assert_line "+ 2 system packages"
}

@test "get_pack_contents hides vscode extensions when show_vscode is false" {
  command -v apt-get &>/dev/null || skip "apt not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  test:
    description: "Test pack"
    apt:
      pkg1: {}
    mise:
      tool1: {version: "1.0"}
    vscode:
      ext1: {version: "1.0"}
      ext2: {version: "2.0"}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="apt"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  # With show_vscode=false, extensions should not appear
  run get_pack_contents "test" "false"
  
  assert_success
  assert_line "tool1"
  assert_line "+ 1 system packages"
  # VS Code extensions should NOT be shown
  refute_line "ext1 (VS Code)"
  refute_line "ext2 (VS Code)"
}

# -----------------------------------------------------------------------------
# get_pack_contents tests (dnf)
# -----------------------------------------------------------------------------

@test "get_pack_contents returns list of pack items (dnf)" {
  command -v dnf &>/dev/null || skip "dnf not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  java:
    description: "Java development"
    dnf:
      java-latest-openjdk: {}
    mise:
      java: { version: "temurin-21" }
      maven: { version: "3.9.6" }
    custom:
      intellij: { version: "2024.1", installer: "install_intellij", tags: ["@optional"] }
    vscode:
      redhat.java: { version: "1.30.0" }
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="dnf"
  source "${DEVBASE_LIBS}/parse-packages.sh"

  run get_pack_contents "java"

  assert_success
  assert_line "java"
  assert_line "maven"
  assert_line "intellij"
  assert_line "redhat.java (VS Code)"
  assert_line "+ 1 system packages"
}

@test "get_pack_contents shows primary tools and labels vscode extensions (dnf)" {
  command -v dnf &>/dev/null || skip "dnf not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  test:
    description: "Test pack"
    dnf:
      pkg1: {}
      pkg2: {}
    mise:
      tool1: {version: "1.0"}
    vscode:
      ext1: {version: "1.0"}
      ext2: {version: "2.0"}
    custom:
      myapp: {version: "1.0", installer: "install_myapp"}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="dnf"
  source "${DEVBASE_LIBS}/parse-packages.sh"

  run get_pack_contents "test"

  assert_success
  assert_line "tool1"
  assert_line "myapp"
  assert_line "ext1 (VS Code)"
  assert_line "ext2 (VS Code)"
  assert_line "+ 2 system packages"
}

@test "get_pack_contents hides vscode extensions when show_vscode is false (dnf)" {
  command -v dnf &>/dev/null || skip "dnf not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core: {}
packs:
  test:
    description: "Test pack"
    dnf:
      pkg1: {}
    mise:
      tool1: {version: "1.0"}
    vscode:
      ext1: {version: "1.0"}
      ext2: {version: "2.0"}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="dnf"
  source "${DEVBASE_LIBS}/parse-packages.sh"

  run get_pack_contents "test" "false"

  assert_success
  assert_line "tool1"
  assert_line "+ 1 system packages"
  refute_line "ext1 (VS Code)"
  refute_line "ext2 (VS Code)"
}

# =============================================================================
# get_tool_version tests
# =============================================================================

@test "get_tool_version returns version from core.custom" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_tool_version "mise"
  
  assert_success
  assert_output "v2025.1.0"
}

@test "get_tool_version returns version from core.mise" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_tool_version "jq"
  
  assert_success
  assert_output "1.7"
}

@test "get_tool_version returns version from pack" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_tool_version "maven"
  
  assert_success
  assert_output "3.9.6"
}

@test "get_tool_version returns empty for unknown tool" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_tool_version "nonexistent"
  
  # Returns success with empty output (no version found)
  assert_output ""
}

# =============================================================================
# get_core_runtimes tests
# =============================================================================

@test "get_core_runtimes returns runtimes for selected packs" {
  export SELECTED_PACKS="java node python"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_core_runtimes
  
  assert_success
  assert_output "java maven gradle node python"
}

@test "get_core_runtimes returns empty for unrecognized packs" {
  export SELECTED_PACKS="unknown-pack"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_core_runtimes
  
  assert_success
  assert_output ""
}

@test "get_core_runtimes includes all runtime types" {
	export SELECTED_PACKS="java node python go ruby"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_core_runtimes
  
  assert_success
  [[ "$output" == *"java"* ]]
  [[ "$output" == *"maven"* ]]
  [[ "$output" == *"gradle"* ]]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"python"* ]]
  [[ "$output" == *"go"* ]]
  [[ "$output" == *"ruby"* ]]
}

# =============================================================================
# generate_mise_config tests
# =============================================================================

@test "generate_mise_config creates valid TOML" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  local output_file="${TEST_DIR}/config.toml"
  generate_mise_config "$output_file"
  
  [[ -f "$output_file" ]]
  grep -q '^\[settings\]$' "$output_file"
  grep -q '^\[tools\]$' "$output_file"
  grep -q '"aqua:junegunn/fzf" = "v0.67.0"' "$output_file"
  grep -q 'java = "temurin-21"' "$output_file"
}

@test "generate_mise_config includes environment section" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  local output_file="${TEST_DIR}/config.toml"
  generate_mise_config "$output_file"
  
  grep -q '^\[env\]$' "$output_file"
  grep -q 'HTTP_PROXY' "$output_file"
  grep -q 'RUBY_CONFIGURE_OPTS' "$output_file"
}

@test "generate_mise_config quotes special characters in tool names" {
  create_test_packages
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  local output_file="${TEST_DIR}/config.toml"
  generate_mise_config "$output_file"
  
  # Tools with : should be quoted
  grep -q '"aqua:junegunn/fzf"' "$output_file"
  # Simple tools should not be quoted
  grep -q '^jq = "1.7"$' "$output_file"
}

# =============================================================================
# Custom overlay integration tests
# =============================================================================

@test "custom overlay adds new packages to core" {
  create_test_packages
  cat > "${TEST_DIR}/packages-custom.yaml" <<'EOF'
core:
  apt:
    new-package: {}
EOF
  
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/packages-custom.yaml"
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_apt_packages
  
  assert_success
  assert_line "curl"
  assert_line "new-package"
}

@test "custom overlay overrides package versions" {
  create_test_packages
  cat > "${TEST_DIR}/packages-custom.yaml" <<'EOF'
core:
  mise:
    fzf: { backend: "aqua:junegunn/fzf", version: "v0.99.0" }
EOF
  
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/packages-custom.yaml"
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_mise_packages
  
  assert_success
  assert_line "aqua:junegunn/fzf|v0.99.0"
  refute_line "aqua:junegunn/fzf|v0.67.0"
}

@test "custom overlay adds new language pack" {
  create_test_packages
  cat > "${TEST_DIR}/packages-custom.yaml" <<'EOF'
packs:
  kotlin:
    description: "Kotlin development"
    mise:
      kotlin: { version: "2.0.0" }
EOF
  
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML="${TEST_DIR}/packages-custom.yaml"
  export SELECTED_PACKS="kotlin"
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_available_packs
  assert_line "kotlin|Kotlin development"
  
  run get_mise_packages
  assert_line "kotlin|2.0.0"
}

# =============================================================================
# get_system_packages tests (multi-distro support)
# =============================================================================

@test "get_system_packages reads common packages" {
  command -v apt-get &>/dev/null || skip "apt not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  common:
    curl: {}
    git: {}
  apt:
    apt-utils: {}
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="apt"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_system_packages
  
  assert_success
  assert_line "curl"
  assert_line "git"
  assert_line "apt-utils"
}

@test "get_system_packages includes pack common and distro-specific" {
  command -v apt-get &>/dev/null || skip "apt not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  common:
    curl: {}
packs:
  java:
    description: "Java development"
    common:
      visualvm: {}
    apt:
      default-jdk: {}
    dnf:
      java-latest-openjdk: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS="java"
  _MERGED_YAML=""
  _PARSE_PKG_MANAGER="apt"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_system_packages
  
  assert_success
  assert_line "curl"
  assert_line "visualvm"
  assert_line "default-jdk"
  # Should NOT include dnf packages when pkg_manager is apt
  refute_line "java-latest-openjdk"
}

@test "get_system_packages uses dnf section on Fedora" {
  command -v dnf &>/dev/null || skip "dnf not available"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  common:
    curl: {}
  apt:
    apt-utils: {}
  dnf:
    dnf-automatic: {}
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  # Override the _get_pkg_manager function for this test
  _get_pkg_manager() { echo "dnf"; }
  
  run get_system_packages
  
  assert_success
  assert_line "curl"
  assert_line "dnf-automatic"
  # Should NOT include apt packages when pkg_manager is dnf
  refute_line "apt-utils"
}

# =============================================================================
# get_flatpak_packages tests
# =============================================================================

@test "get_flatpak_packages returns app_id|remote format" {
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  flatpak:
    org.chromium.Chromium: {remote: "flathub"}
    org.example.App: {}
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  run get_flatpak_packages
  
  assert_success
  assert_line "org.chromium.Chromium|flathub"
  assert_line "org.example.App|flathub"
}

# =============================================================================
# get_app_store_packages tests
# =============================================================================

@test "get_app_store_packages returns snap packages on Ubuntu" {
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<'EOF'
core:
  snap:
    chromium: {}
    microk8s: {options: "--classic"}
  flatpak:
    org.chromium.Chromium: {}
packs: {}
EOF
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export PACKAGES_CUSTOM_YAML=""
  export SELECTED_PACKS=""
  _MERGED_YAML=""
  source "${DEVBASE_LIBS}/parse-packages.sh"
  
  # Mock get_app_store to return snap
  get_app_store() { echo "snap"; }
  
  run get_app_store_packages
  
  assert_success
  assert_line "chromium|"
  assert_line "microk8s|--classic"
}
