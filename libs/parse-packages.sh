#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Parse packages.yaml and provide package lists for installers
# Requires: yq

set -uo pipefail

# Global: Path to packages.yaml (set by caller or default)
PACKAGES_YAML="${PACKAGES_YAML:-${DEVBASE_DOT}/.config/devbase/packages.yaml}"
PACKAGES_CUSTOM_YAML="${PACKAGES_CUSTOM_YAML:-}"

# Selected packs (set by caller, space-separated)
SELECTED_PACKS="${SELECTED_PACKS:-java node python go ruby rust vscode-editor}"

# Cache for merged packages (avoids re-reading yaml repeatedly)
_MERGED_YAML=""

# Brief: Get merged packages.yaml content (base + custom if exists)
# Returns: Merged YAML to stdout (cached after first call)
_get_merged_packages() {
  if [[ -n "$_MERGED_YAML" ]]; then
    echo "$_MERGED_YAML"
    return
  fi

  if [[ -n "$PACKAGES_CUSTOM_YAML" && -f "$PACKAGES_CUSTOM_YAML" ]]; then
    _MERGED_YAML=$(yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$PACKAGES_YAML" "$PACKAGES_CUSTOM_YAML")
  else
    _MERGED_YAML=$(cat "$PACKAGES_YAML")
  fi
  echo "$_MERGED_YAML"
}

# Brief: Check if package should be skipped based on tags
# Params: $1 = tags string (e.g., '["@skip-wsl"]' or '')
# Returns: 0 if should skip, 1 if should install
_should_skip() {
  local tags="$1"
  [[ -z "$tags" || "$tags" == "null" ]] && return 1
  [[ "$tags" == *"@skip-wsl"* ]] && is_wsl 2>/dev/null && return 0
  return 1
}

# Brief: Process packages from a yq path for apt type
# Params: $1=yaml content, $2=yq path (e.g., ".core.apt" or ".packs.java.apt")
_process_apt() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local tags
    tags=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].tags // \"\"")
    _should_skip "$tags" || echo "$pkg"
  done
}

# Brief: Process packages from a yq path for snap type
# Params: $1=yaml content, $2=yq path
_process_snap() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local tags options
    tags=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].tags // \"\"")
    options=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].options // \"\"")
    _should_skip "$tags" || echo "${pkg}|${options}"
  done
}

# Brief: Process packages from a yq path for mise type
# Params: $1=yaml content, $2=yq path
_process_mise() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r tool; do
    [[ -z "$tool" ]] && continue
    local backend version options tags tool_key
    backend=$(echo "$yaml" | yq -r "${path}[\"$tool\"].backend // \"\"")
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    options=$(echo "$yaml" | yq -r "${path}[\"$tool\"].options // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$tool\"].tags // \"\"")

    _should_skip "$tags" && continue

    # Build tool key for mise config
    if [[ -n "$backend" && "$backend" != "null" ]]; then
      tool_key="$backend"
      # Handle ubi backend options
      if [[ "$backend" == ubi:* && -n "$options" && "$options" != "null" ]]; then
        local provider exe opts_str=""
        provider=$(echo "$yaml" | yq -r "${path}[\"$tool\"].options.provider // \"\"")
        exe=$(echo "$yaml" | yq -r "${path}[\"$tool\"].options.exe // \"\"")
        [[ -n "$provider" && "$provider" != "null" ]] && opts_str="provider=$provider"
        [[ -n "$exe" && "$exe" != "null" ]] && opts_str="${opts_str:+$opts_str,}exe=$exe"
        [[ -n "$opts_str" ]] && tool_key="${backend}[${opts_str}]"
      fi
    else
      tool_key="$tool"
    fi
    echo "${tool_key}|${version}"
  done
}

# Brief: Process packages from a yq path for custom type
# Params: $1=yaml content, $2=yq path
_process_custom() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r tool; do
    [[ -z "$tool" ]] && continue
    local version installer tags
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    installer=$(echo "$yaml" | yq -r "${path}[\"$tool\"].installer // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$tool\"].tags // \"\"")
    _should_skip "$tags" && continue
    echo "${tool}|${version}|${installer}|${tags}"
  done
}

# Brief: Process packages from a yq path for vscode type
# Params: $1=yaml content, $2=yq path
_process_vscode() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r ext; do
    [[ -z "$ext" ]] && continue
    local version tags
    version=$(echo "$yaml" | yq -r "${path}[\"$ext\"].version // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$ext\"].tags // \"\"")
    _should_skip "$tags" && continue
    echo "${ext}|${version}|${tags}"
  done
}

# Brief: Get apt packages from core + selected packs
# Output: Package names, one per line
get_apt_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_apt "$yaml" ".core.apt"
  for pack in $SELECTED_PACKS; do
    _process_apt "$yaml" ".packs.${pack}.apt"
  done
}

# Brief: Get snap packages from core + selected packs
# Output: Lines of "package_name|options"
get_snap_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_snap "$yaml" ".core.snap"
  for pack in $SELECTED_PACKS; do
    _process_snap "$yaml" ".packs.${pack}.snap"
  done
}

# Brief: Get mise tools from core + selected packs
# Output: Lines of "tool_key|version"
get_mise_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_mise "$yaml" ".core.mise"
  for pack in $SELECTED_PACKS; do
    _process_mise "$yaml" ".packs.${pack}.mise"
  done
}

# Brief: Get custom tools from core + selected packs
# Output: Lines of "tool|version|installer|tags"
get_custom_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_custom "$yaml" ".core.custom"
  for pack in $SELECTED_PACKS; do
    _process_custom "$yaml" ".packs.${pack}.custom"
  done
}

# Brief: Get vscode extensions from core + selected packs
# Output: Lines of "extension_id|version|tags"
get_vscode_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_vscode "$yaml" ".core.vscode"
  for pack in $SELECTED_PACKS; do
    _process_vscode "$yaml" ".packs.${pack}.vscode"
  done
}

# Brief: Get available packs with descriptions
# Output: Lines of "pack_name|description"
get_available_packs() {
  local yaml
  yaml=$(_get_merged_packages)
  echo "$yaml" | yq -r '.packs | keys | .[]' | while read -r pack; do
    local desc
    desc=$(echo "$yaml" | yq -r ".packs.${pack}.description // \"\"")
    echo "${pack}|${desc}"
  done
}

# Brief: Get version of a specific tool from packages.yaml
# Params: $1 = tool name (e.g., "mise", "node", "vscode")
# Output: Version string
get_tool_version() {
  local tool="$1"
  local yaml version
  yaml=$(_get_merged_packages)

  # Check core.custom, core.mise, then packs
  for path in ".core.custom" ".core.mise"; do
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    [[ -n "$version" && "$version" != "null" ]] && echo "$version" && return
  done

  for pack in $SELECTED_PACKS; do
    for type in "custom" "mise"; do
      version=$(echo "$yaml" | yq -r ".packs.${pack}.${type}[\"$tool\"].version // \"\"")
      [[ -n "$version" && "$version" != "null" ]] && echo "$version" && return
    done
  done
}

# Brief: Get core language runtimes from selected packs
# Output: Space-separated list of runtime names
get_core_runtimes() {
  local runtimes=""
  for pack in $SELECTED_PACKS; do
    case "$pack" in
    java) runtimes+=" java maven gradle" ;;
    node) runtimes+=" node" ;;
    python) runtimes+=" python" ;;
    go) runtimes+=" go" ;;
    ruby) runtimes+=" ruby" ;;
    rust) runtimes+=" rust" ;;
    esac
  done
  echo "${runtimes# }"
}

# Brief: Generate mise config.toml from packages.yaml
# Params: $1 = output file path
generate_mise_config() {
  local output_file="$1"

  cat >"$output_file" <<'EOF'
# Auto-generated from packages.yaml - DO NOT EDIT DIRECTLY
# To modify tools, edit packages.yaml and re-run setup

[settings]
experimental = true
legacy_version_file = false
asdf_compat = false
jobs = 6
yes = true
http_timeout = "90s"

[env]
HTTP_PROXY = "{{ get_env(name='HTTP_PROXY', default='') }}"
HTTPS_PROXY = "{{ get_env(name='HTTPS_PROXY', default='') }}"
NO_PROXY = "{{ get_env(name='NO_PROXY', default='') }}"
http_proxy = "{{ get_env(name='http_proxy', default='') }}"
https_proxy = "{{ get_env(name='https_proxy', default='') }}"
no_proxy = "{{ get_env(name='no_proxy', default='') }}"
PIP_INDEX_URL = "{{ get_env(name='PIP_INDEX_URL', default='') }}"
NPM_CONFIG_REGISTRY = "{{ get_env(name='NPM_CONFIG_REGISTRY', default='') }}"
RUBY_CONFIGURE_OPTS = "--with-openssl-dir=/usr"

[tools]
EOF

  get_mise_packages | while IFS='|' read -r tool_key version; do
    [[ -z "$tool_key" || -z "$version" ]] && continue
    if [[ "$tool_key" == *:* || "$tool_key" == *[* ]]; then
      echo "\"$tool_key\" = \"$version\""
    else
      echo "$tool_key = \"$version\""
    fi
  done >>"$output_file"
}
