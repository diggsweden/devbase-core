#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Create and populate temporary dotfiles directory
# Params: None
# Uses: _DEVBASE_TEMP, DEVBASE_DOT (globals)
# Returns: Prints temp directory path to stdout, returns 0 on success, 1 on error
# Side-effects: Creates directory and copies files
prepare_temp_dotfiles_directory() {
  validate_var_set "_DEVBASE_TEMP" || return 1
  validate_dir_exists "${DEVBASE_DOT}" "Dotfiles directory" || return 1

  local temp_dotfiles="${_DEVBASE_TEMP}/dotfiles"
  # shellcheck disable=SC2153 # DEVBASE_DOT is exported in setup.sh
  cp -r "${DEVBASE_DOT}" "${temp_dotfiles}"
  echo "$temp_dotfiles"
}

# Brief: Count total files in dotfiles directory
# Params: $1 - temp_dotfiles directory path
# Returns: File count to stdout
# Side-effects: None (read-only)
count_total_files() {
  local temp_dotfiles="$1"
  validate_not_empty "$temp_dotfiles" "temp_dotfiles parameter" || return 1
  validate_dir_exists "$temp_dotfiles" "Temp dotfiles directory" || return 1

  find "${temp_dotfiles}" -type f | wc -l
}

# Brief: Count template files in dotfiles directory
# Params: $1 - temp_dotfiles directory path
# Returns: Template count to stdout
# Side-effects: None (read-only)
count_templates() {
  local temp_dotfiles="$1"
  validate_not_empty "$temp_dotfiles" "temp_dotfiles parameter" || return 1
  validate_dir_exists "$temp_dotfiles" "Temp dotfiles directory" || return 1

  find "${temp_dotfiles}" -name "*.template" -type f | wc -l
}

# Brief: Count custom overlay templates
# Params: None
# Uses: DEVBASE_CUSTOM_TEMPLATES (global, optional)
# Returns: Custom overlay count to stdout
# Side-effects: None (read-only)
count_custom_overlays() {
  [[ -z "${DEVBASE_CUSTOM_TEMPLATES:-}" ]] && {
    echo 0
    return 0
  }
  [[ ! -d "${DEVBASE_CUSTOM_TEMPLATES}" ]] && {
    echo 0
    return 0
  }

  find "${DEVBASE_CUSTOM_TEMPLATES}" -name "*.template" -type f | wc -l
}

# Brief: Apply theme and custom template overlays to dotfiles
# Params: $1 - temp_dotfiles directory path
# Uses: DEVBASE_CUSTOM_TEMPLATES, DEVBASE_THEME (globals)
# Returns: 0 on success, 1 on error
# Side-effects: Modifies files in temp_dotfiles directory
apply_customizations() {
  local temp_dotfiles="$1"
  validate_not_empty "$temp_dotfiles" "temp_dotfiles parameter" || return 1
  validate_dir_exists "$temp_dotfiles" "Temp dotfiles directory" || return 1

  if [[ -n "${DEVBASE_CUSTOM_TEMPLATES}" ]] && [[ -d "${DEVBASE_CUSTOM_TEMPLATES}" ]]; then
    copy_custom_templates_to_temp "${temp_dotfiles}"
  fi

  apply_theme "$DEVBASE_THEME"
  sync_mise_config_versions
}

# Brief: Process all templates and tool-specific configurations
# Params: $1 - temp_dotfiles directory path
# Uses: None (delegates to other functions)
# Returns: 0 on success, 1 on error
# Side-effects: Processes templates, generates tool configs
process_templates_and_tools() {
  local temp_dotfiles="$1"
  validate_not_empty "$temp_dotfiles" "temp_dotfiles parameter" || return 1

  process_all_templates "${temp_dotfiles}"
  process_maven_templates
  process_gradle_templates
  process_container_templates
}

# Brief: Apply custom non-template configuration files
# Params: None
# Uses: DEVBASE_CUSTOM_TEMPLATES, process_custom_templates, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Processes custom config files, prints count
apply_custom_configs() {
  [[ ! -n "${DEVBASE_CUSTOM_TEMPLATES}" ]] || [[ ! -d "${DEVBASE_CUSTOM_TEMPLATES}" ]] && return 0

  show_progress info "Applying custom organization configs..."
  local custom_configs
  custom_configs=$(find "${DEVBASE_CUSTOM_TEMPLATES}" -type f ! -name "*.template" ! -name "README*" | wc -l)
  process_custom_templates
  show_progress success "Custom configs applied ($custom_configs files)"
}

# Brief: Install Windows Terminal theme files on WSL systems
# Params: None
# Uses: XDG_DATA_HOME, DEVBASE_FILES, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Creates theme directory, copies theme files (WSL only)
install_wsl_terminal_themes() {
  uname -r | grep -qi microsoft || return 0

  local wt_theme_dir="${XDG_DATA_HOME}/devbase/files/windows-terminal"
  show_progress info "Copying Windows Terminal theme files to $wt_theme_dir..."
  mkdir -p "$wt_theme_dir"

  if [[ -d "${DEVBASE_FILES}/windows-terminal" ]]; then
    if cp -r "${DEVBASE_FILES}/windows-terminal/"* "$wt_theme_dir/" 2>/dev/null; then
      show_progress success "Windows Terminal theme files copied (8 files)"
    else
      show_progress warning "Windows Terminal theme files copy failed"
    fi
  else
    show_progress warning "Windows Terminal theme source not found: ${DEVBASE_FILES}/windows-terminal"
  fi
}

# Brief: Install processed dotfiles to final target location
# Params: $1 - temp_dotfiles directory path
# Uses: XDG_CONFIG_HOME, merge_dotfiles_with_backup, install_wsl_terminal_themes, show_progress (globals/functions)
# Returns: 0 on success, 1 on validation failure
# Side-effects: Merges dotfiles to home, deletes .template files, installs WSL themes
install_dotfiles_to_target() {
  local temp_dotfiles="$1"
  validate_not_empty "$temp_dotfiles" "temp_dotfiles parameter" || return 1
  validate_dir_exists "$temp_dotfiles" "Temp dotfiles directory" || return 1

  show_progress info "Installing configuration files..."
  merge_dotfiles_with_backup "${temp_dotfiles}"

  find "${XDG_CONFIG_HOME}" -name "*.template" -type f -delete 2>/dev/null || true
  install_wsl_terminal_themes
}

process_and_copy_dotfiles() {
  show_progress info "Processing dotfiles and templates..."

  local temp_dotfiles
  temp_dotfiles=$(prepare_temp_dotfiles_directory)

  local total_files template_count custom_overlays
  total_files=$(count_total_files "$temp_dotfiles")
  template_count=$(count_templates "$temp_dotfiles")
  custom_overlays=$(count_custom_overlays)

  apply_customizations "$temp_dotfiles"
  process_templates_and_tools "$temp_dotfiles"

  local msg="Dotfiles processed ($total_files files"
  [[ $template_count -gt 0 ]] && msg="${msg}, $template_count templates"
  [[ ${custom_overlays:-0} -gt 0 ]] && msg="${msg}, $custom_overlays custom overlays"
  msg="${msg}, theme: ${DEVBASE_THEME})"
  show_progress success "$msg"

  apply_custom_configs
  install_dotfiles_to_target "$temp_dotfiles"

  local backup_dir="${XDG_DATA_HOME}/devbase/backup/dot_backup"
  local backed_up=0
  [[ -d "$backup_dir" ]] && backed_up=$(find "$backup_dir" -type f 2>/dev/null | wc -l)

  msg="Configuration installed ($total_files files"
  [[ $backed_up -gt 0 ]] && msg="${msg}, $backed_up backed up"
  msg="${msg})"
  show_progress success "$msg"
}

validate_custom_template() {
  local template_name="$1"
  local temp_dir="$2"

  # List of templates that are custom-only (don't require vanilla match)
  local custom_only_templates=(
    "registries.conf.template"
    "init.gradle.template"
    "maven-settings.xml.template"
    "settings.registry.xml.template"
    "settings.registry.proxy.xml.template"
    "settings.proxy.xml.template"
    ".testcontainers.properties.template"
  )

  # Check if this is a custom-only template
  for custom_template in "${custom_only_templates[@]}"; do
    if [[ "$template_name" == "$custom_template" ]]; then
      return 2 # Special return code for custom-only templates
    fi
  done

  # Normal validation: check if template exists in vanilla
  if ! find "$temp_dir" -name "$template_name" -type f -quit | grep -q .; then
    show_progress warning "Custom template '$template_name' not found in vanilla (ignored)"
    show_progress info "See available templates: ls ${DEVBASE_ROOT}/dot -name '*.template'"
    return 1
  fi

  return 0
}

# Brief: Copy validated custom templates to temp dotfiles directory
# Params: $1 - temp_dir path
# Uses: DEVBASE_CUSTOM_TEMPLATES, validate_custom_template (globals/functions)
# Returns: 0 always
# Side-effects: Overwrites vanilla templates with custom versions
copy_custom_templates_to_temp() {
  local temp_dir="$1"

  for template in "${DEVBASE_CUSTOM_TEMPLATES}"/*.template; do
    [[ -f "$template" ]] || continue

    local template_name
    template_name=$(basename "$template")

    # Validate template
    validate_custom_template "$template_name" "$temp_dir"
    local validation_result=$?

    # validation_result: 0 = vanilla override, 1 = invalid, 2 = custom-only
    if [[ $validation_result -eq 1 ]]; then
      continue # Invalid template, skip
    elif [[ $validation_result -eq 2 ]]; then
      continue # Custom-only template, will be processed by process_custom_templates()
    fi

    # Find matching vanilla template and replace it
    local target_location
    target_location=$(find "${temp_dir}" -name "$template_name" -type f 2>/dev/null | head -1)

    if [[ -n "$target_location" ]]; then
      cp "$template" "$target_location"
    fi
  done
  return 0
}

# Brief: Detect available clipboard utility based on platform
# Params: None
# Uses: XDG_SESSION_TYPE (global)
# Returns: Echoes clipboard command to stdout, empty if none found
detect_clipboard_utility() {
  if uname -r | grep -qi microsoft; then
    if [[ -x /mnt/c/Windows/System32/clip.exe ]]; then
      echo "/mnt/c/Windows/System32/clip.exe"
    elif command -v clip.exe &>/dev/null; then
      echo "clip.exe"
    fi
  elif [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v wl-copy &>/dev/null; then
    echo "wl-copy"
  elif command -v xclip &>/dev/null; then
    echo "xclip -selection clipboard"
  elif command -v xsel &>/dev/null; then
    echo "xsel --clipboard"
  else
    echo "smart-copy"
  fi
}

process_all_templates() {
  local temp_dir="$1"

  export ZELLIJ_COPY_COMMAND
  ZELLIJ_COPY_COMMAND=$(detect_clipboard_utility)

  while IFS= read -r -d '' template; do
    local output="${template%.template}"

    # Standard template processing with envsubst_preserve_undefined
    envsubst_preserve_undefined "$template" "$output"

    # Safe delete: only remove files that explicitly end with .template
    [[ "$template" == *.template ]] && rm "$template"
  done < <(find "${temp_dir}" -name "*.template" -type f -print0)

  if [[ -n "${DEVBASE_PROXY_URL}" ]]; then
    local proxy_target="${temp_dir}/.config/fish/conf.d/00-proxy.fish"
    mkdir -p "$(dirname "$proxy_target")"
    generate_fish_proxy_config "$proxy_target"

    # Install proxy management function (only when proxy is configured)
    local proxy_func_target="${temp_dir}/.config/fish/functions/devbase-proxy.fish"
    mkdir -p "$(dirname "$proxy_func_target")"
    cp "${DEVBASE_FILES}/fish-functions/devbase-proxy.fish" "$proxy_func_target"
  fi

  if [[ -n "${DEVBASE_REGISTRY_URL}" ]]; then
    local registry_target="${temp_dir}/.config/fish/conf.d/00-registry.fish"
    mkdir -p "$(dirname "$registry_target")"
    generate_fish_registry_config "$registry_target"
  fi

  return 0
}

# Brief: Parse URL components (protocol, host, port, username, password, path)
# Params: $1 - url, $2 - component (protocol|host|port|username|password|path)
# Returns: Echoes component value to stdout
parse_url() {
  local url="$1"
  local component="$2"

  case "$component" in
  protocol)
    # Extract everything before ://
    echo "$url" | sed 's|^\([^:]*\)://.*|\1|'
    ;;
  host)
    # Remove protocol, remove auth if present, remove port/path
    echo "$url" |
      sed 's|^[^:]*://||' | # Remove protocol (http://)
      sed 's|^[^@]*@||' |   # Remove auth (user:pass@)
      sed 's|[:/].*||'      # Remove port/path (:8080/path)
    ;;
  port)
    # Extract port number, or return default based on protocol
    local port=$(echo "$url" |
      sed 's|^[^:]*://||' |                # Remove protocol
      sed 's|^[^@]*@||' |                  # Remove auth
      sed -n 's|^[^:]*:\([0-9]*\).*|\1|p') # Extract port number

    if [[ -n "$port" ]]; then
      echo "$port"
    else
      # Return default port based on protocol
      case "$(parse_url "$url" protocol)" in
      http) echo "80" ;;
      https) echo "443" ;;
      *) echo "" ;;
      esac
    fi
    ;;
  username)
    # Extract username from user:pass@ pattern
    echo "$url" | sed -n 's|^[^:]*://\([^:]*\):.*@.*|\1|p'
    ;;
  password)
    # Extract password from user:pass@ pattern
    echo "$url" | sed -n 's|^[^:]*://[^:]*:\([^@]*\)@.*|\1|p'
    ;;
  path)
    # Extract path after hostname (including leading /)
    local path=$(echo "$url" |
      sed 's|^[^:]*://||' | # Remove protocol
      sed 's|^[^@]*@||' |   # Remove auth
      sed 's|^[^/]*||')     # Remove hostname:port

    # Return path or default to /
    echo "${path:-/}"
    ;;
  esac
}

# Brief: Generate Fish shell proxy configuration file
# Params: $1 - target file path
# Uses: DEVBASE_PROXY_URL, DEVBASE_NO_PROXY_DOMAINS, DEVBASE_NO_PROXY_JAVA, parse_url, validate_not_empty (globals/functions)
# Returns: 0 on success, 1 on validation failure
# Side-effects: Creates proxy config file with HTTP_PROXY, HTTPS_PROXY, and Java proxy settings
generate_fish_proxy_config() {
  local target="$1"
  validate_not_empty "$target" "target path" || return 1

  mkdir -p "$(dirname "$target")"

  if [[ -n "${DEVBASE_PROXY_URL}" ]]; then
    local no_proxy_hosts="${DEVBASE_NO_PROXY_DOMAINS}"

    local proxy_host
    proxy_host=$(parse_url "${DEVBASE_PROXY_URL}" host)
    local proxy_port
    proxy_port=$(parse_url "${DEVBASE_PROXY_URL}" port)

    cat >"$target" <<EOF
# Proxy configuration for development tools
# Generated from DEVBASE_PROXY_URL during setup
# Note: DEVBASE_PROXY_URL is not exported at runtime (only used during setup)

set -l no_proxy_hosts "${no_proxy_hosts}"

# Java proxy settings (Java expects pipe separator for nonProxyHosts)
# Note: Java doesn't support authenticated proxies via system properties.
# Applications must handle authentication programmatically or use tools like CNTLM
# Use DEVBASE_NO_PROXY_JAVA if provided (should be in pipe-separated format)
set -l no_proxy_java "${DEVBASE_NO_PROXY_JAVA:-}"

# Preserve existing JAVA_TOOL_OPTIONS (like trustStore settings) and append proxy settings
if test -n "\$JAVA_TOOL_OPTIONS"
    set -gx JAVA_TOOL_OPTIONS "\$JAVA_TOOL_OPTIONS -Dhttp.proxyHost=${proxy_host} -Dhttp.proxyPort=${proxy_port} -Dhttps.proxyHost=${proxy_host} -Dhttps.proxyPort=${proxy_port} -Dhttp.nonProxyHosts=\$no_proxy_java"
else
    set -gx JAVA_TOOL_OPTIONS "-Dhttp.proxyHost=${proxy_host} -Dhttp.proxyPort=${proxy_port} -Dhttps.proxyHost=${proxy_host} -Dhttps.proxyPort=${proxy_port} -Dhttp.nonProxyHosts=\$no_proxy_java"
end

# Gradle proxy settings (including nonProxyHosts to match JAVA_TOOL_OPTIONS)
set -gx GRADLE_OPTS "-Dhttp.proxyHost=${proxy_host} -Dhttp.proxyPort=${proxy_port} -Dhttps.proxyHost=${proxy_host} -Dhttps.proxyPort=${proxy_port} -Dhttp.nonProxyHosts=\$no_proxy_java"

# Standard proxy environment variables
set -gx HTTP_PROXY "${DEVBASE_PROXY_URL}"
set -gx HTTPS_PROXY "${DEVBASE_PROXY_URL}"
set -gx NO_PROXY "\$no_proxy_hosts"

set -gx http_proxy "\$HTTP_PROXY"
set -gx https_proxy "\$HTTPS_PROXY"
set -gx no_proxy "\$NO_PROXY"
EOF
  else
    cat >"$target" <<'EOF'
# Proxy configuration disabled
# Set DEVBASE_PROXY_URL to enable (e.g., http://proxy.company.com:8080)
EOF
  fi
  return 0
}

# Extract hostname from URL (strip protocol, path, and port)
# Example: "https://registry.company.com:8080/path" -> "registry.company.com"
extract_hostname() {
  local url="$1"
  echo "$url" |
    sed -E 's|^[^:]+://||' | # Remove protocol (https://)
    sed -E 's|/.*$||' |      # Remove path (/path)
    sed -E 's|:[0-9]+$||'    # Remove port (:8080)
}

generate_fish_registry_config() {
  local target="$1"
  mkdir -p "$(dirname "$target")"

  if [[ -n "${DEVBASE_REGISTRY_URL}" ]]; then
    local registry_host
    registry_host=$(extract_hostname "${DEVBASE_REGISTRY_URL}")

    cat >"$target" <<EOF
# Registry configuration for development tools
# Generated from DEVBASE_REGISTRY_URL during setup
# Note: DEVBASE_REGISTRY_URL is not exported at runtime (only used during setup)

# Testcontainers registry configuration
set -gx TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX "${DEVBASE_CONTAINERS_REGISTRY:-${DEVBASE_REGISTRY_URL}:5050}/"

# Python pip registry configuration
# Uses internal PyPI mirror with SSL verification via system certificates
set -gx PIP_INDEX_URL "${DEVBASE_REGISTRY_URL}/pypi/simple"

EOF
  else
    cat >"$target" <<'EOF'
# Registry configuration disabled
# Set DEVBASE_REGISTRY_URL to enable (e.g., https://registry.company.com)
EOF
  fi
  return 0
}

process_template_file() {
  local file="$1"
  local filename="$2"
  local template_name="${filename%.template}"
  local target_file=""

  # Skip templates now handled by dedicated functions or conditionally processed
  case "$template_name" in
  registries.conf | init.gradle | maven-settings.xml | settings.registry.proxy.xml | settings.registry.xml | settings.proxy.xml)
    # These are processed by process_maven_templates, process_gradle_templates, process_container_templates
    rm "$file" 2>/dev/null || true
    return 0
    ;;
  .testcontainers.properties)
    # Skip if no container registry configured
    if [[ -z "${DEVBASE_CONTAINERS_REGISTRY:-}" ]] && [[ -z "${DEVBASE_REGISTRY_URL:-}" ]]; then
      rm "$file" 2>/dev/null || true
      return 0
    fi
    target_file="${HOME}/.testcontainers.properties"
    ;;
  esac

  # Only set target_file if not already set above
  if [[ -z "$target_file" ]]; then
    case "$template_name" in
    npmrc)
      target_file="${HOME}/.npmrc"
      ;;
    gradle.properties)
      target_file="${HOME}/.gradle/gradle.properties"
      ;;
    *)
      target_file="${HOME}/.${template_name}"
      ;;
    esac
  fi

  envsubst_preserve_undefined "$file" "$target_file"

  [[ "$file" == *.template ]] && rm "$file"
}

process_append_file() {
  local file="$1"
  local filename="$2"
  local target_name="${filename%.append}"
  local target_file=""

  case "$target_name" in
  known_hosts)
    target_file="${HOME}/.ssh/known_hosts"
    touch "$target_file"

    while IFS= read -r line; do
      if [[ -n "$line" ]] && ! grep -qF "$line" "$target_file" 2>/dev/null; then
        echo "$line" >>"$target_file"
      fi
    done <"$file"
    ;;
  bashrc)
    target_file="${HOME}/.bashrc"
    cat "$file" >>"$target_file"
    ;;
  *)
    target_file="${HOME}/.${target_name}"
    cat "$file" >>"$target_file"
    ;;
  esac
}

process_service_file() {
  local file="$1"
  cp "$file" "$XDG_CONFIG_HOME/systemd/user/"
}

process_config_file() {
  local file="$1"
  local filename="$2"
  cp "$file" "$XDG_CONFIG_HOME/${filename}"
}

process_generic_file() {
  local file="$1"
  local filename="$2"

  # Handle Fish configuration files specially
  if [[ "$filename" == *.fish ]]; then
    # Fish config files go to ~/.config/fish/conf.d/
    local fish_conf_dir="${XDG_CONFIG_HOME}/fish/conf.d"
    mkdir -p "$fish_conf_dir"
    cp "$file" "${fish_conf_dir}/${filename}"
  # Handle Maven settings.xml specially
  elif [[ "$filename" == "maven-settings.xml" ]]; then
    mkdir -p "${HOME}/.m2"
    cp "$file" "${HOME}/.m2/settings.xml"
  elif [[ "$filename" == *.* ]]; then
    cp "$file" "${HOME}/.${filename}"
  else
    cp "$file" "${XDG_BIN_HOME}/"
    chmod +x "${XDG_BIN_HOME}/${filename}"
  fi
}

process_single_custom_file() {
  local file="$1"
  local filename
  filename=$(basename "$file")

  case "$filename" in
  *.template)
    process_template_file "$file" "$filename"
    ;;
  *.append)
    process_append_file "$file" "$filename"
    ;;
  *.service)
    process_service_file "$file" "$filename"
    ;;
  *.conf | *.config)
    process_config_file "$file" "$filename"
    ;;
  *)
    process_generic_file "$file" "$filename"
    ;;
  esac
}

process_maven_templates() {
  process_maven_templates_yaml
}

process_maven_templates_yaml() {
  local maven_yaml_dir="${DEVBASE_FILES}/maven-templates/yaml"
  local target_file="${HOME}/.m2/settings.xml"
  local temp_dir="${_DEVBASE_TEMP}/maven-yaml"

  mkdir -p "$temp_dir"

  # Check for yq
  if ! command -v yq &>/dev/null; then
    show_progress warning "yq not found, skipping Maven configuration"
    show_progress info "Install with: mise install yq"
    return 1
  fi

  # Verify yq supports XML output
  if ! yq --help 2>&1 | grep -q "output.*xml"; then
    show_progress warning "yq does not support XML output, skipping Maven configuration"
    return 1
  fi

  # Collect YAML fragments to merge
  local yaml_fragments=()
  local config_desc=""

  # Start with base (XML namespaces)
  if [[ -f "${maven_yaml_dir}/base.yaml" ]]; then
    yaml_fragments+=("${maven_yaml_dir}/base.yaml")
  fi

  # Add proxy config if needed
  if [[ -n "${DEVBASE_PROXY_URL:-}" ]] && [[ -f "${maven_yaml_dir}/proxy.yaml" ]]; then
    local proxy_processed="${temp_dir}/proxy.yaml"
    envsubst_preserve_undefined "${maven_yaml_dir}/proxy.yaml" "$proxy_processed"
    yaml_fragments+=("$proxy_processed")
    config_desc="proxy"
  fi

  # Add registry/mirror if configured
  if [[ -n "${DEVBASE_REGISTRY_URL:-}" ]] && [[ -f "${maven_yaml_dir}/registry.yaml" ]]; then
    local registry_processed="${temp_dir}/registry.yaml"
    envsubst_preserve_undefined "${maven_yaml_dir}/registry.yaml" "$registry_processed"
    yaml_fragments+=("$registry_processed")
    config_desc="${config_desc:+$config_desc + }registry"
  fi

  # Add custom repos if available
  if [[ -f "${DEVBASE_CUSTOM_TEMPLATES}/maven-repos.yaml" ]]; then
    local custom_processed="${temp_dir}/maven-repos.yaml"
    envsubst_preserve_undefined "${DEVBASE_CUSTOM_TEMPLATES}/maven-repos.yaml" "$custom_processed"
    yaml_fragments+=("$custom_processed")
    config_desc="${config_desc:+$config_desc + }custom repos"
  fi

  # Skip if no fragments
  if [[ ${#yaml_fragments[@]} -eq 0 ]]; then
    return 0
  fi

  show_progress info "Configuring Maven with ${config_desc}"

  # Merge YAML fragments
  local merged_yaml="${temp_dir}/merged.yaml"

  if [[ ${#yaml_fragments[@]} -eq 1 ]]; then
    cp "${yaml_fragments[0]}" "$merged_yaml"
  else
    yq eval-all '
      . as $item ireduce ({}; 
        .settings = (.settings // {}) * ($item.settings // {}) |
        .settings.proxies.proxy = ((.settings.proxies.proxy // []) + ($item.proxies.proxy // [])) |
        .settings.mirrors.mirror = ((.settings.mirrors.mirror // {}) * ($item.mirrors.mirror // {})) |
        .settings.profiles.profile = ((.settings.profiles.profile // []) + ($item.profiles.profile // [])) |
        .settings.activeProfiles.activeProfile = ((.settings.activeProfiles.activeProfile // []) + ($item.activeProfiles.activeProfile // []))
      )
    ' "${yaml_fragments[@]}" >"$merged_yaml" 2>/dev/null

    if [[ $? -ne 0 ]]; then
      show_progress error "Failed to merge YAML fragments"
      return 1
    fi
  fi

  # Convert YAML to XML
  yq -o=xml "$merged_yaml" >"$target_file" 2>/dev/null

  if [[ $? -eq 0 ]] && [[ -f "$target_file" ]]; then
    show_progress success "Maven settings generated from YAML"
  else
    show_progress error "Failed to generate Maven settings.xml"
    return 1
  fi
}

process_gradle_templates() {
  # Skip if no registry configured
  [[ -z "${DEVBASE_REGISTRY_URL:-}" ]] && return 0

  local gradle_templates_dir="${DEVBASE_FILES}/gradle-templates"
  local target_file="${HOME}/.gradle/init.gradle"
  local template_to_use=""

  mkdir -p "${HOME}/.gradle"

  # Check custom first, then core
  if [[ -f "${DEVBASE_CUSTOM_TEMPLATES}/init.gradle.template" ]]; then
    template_to_use="${DEVBASE_CUSTOM_TEMPLATES}/init.gradle.template"
    show_progress info "Configuring Gradle with custom repository settings"
  elif [[ -f "${gradle_templates_dir}/init.gradle.template" ]]; then
    template_to_use="${gradle_templates_dir}/init.gradle.template"
    show_progress info "Configuring Gradle with repository mirror"
  fi

  if [[ -n "$template_to_use" ]] && [[ -f "$template_to_use" ]]; then
    envsubst_preserve_undefined "$template_to_use" "$target_file"
    show_progress success "Gradle init script configured"
  fi
}

process_container_templates() {
  # Skip if no registry configured
  if [[ -z "${DEVBASE_CONTAINERS_REGISTRY:-}" ]] && [[ -z "${DEVBASE_REGISTRY_URL:-}" ]]; then
    return 0
  fi

  local container_templates_dir="${DEVBASE_FILES}/container-templates"
  local target_file="${XDG_CONFIG_HOME}/containers/registries.conf"
  local template_to_use=""

  mkdir -p "$(dirname "$target_file")"

  # Derive DEVBASE_REGISTRY_CONTAINER if not set
  # Extract host:port from registry URL (without protocol and path)
  if [[ -z "${DEVBASE_REGISTRY_CONTAINER:-}" ]]; then
    export DEVBASE_REGISTRY_CONTAINER
    if [[ -n "${DEVBASE_CONTAINERS_REGISTRY:-}" ]]; then
      # Remove protocol and path: "https://host:port/path" -> "host:port"
      DEVBASE_REGISTRY_CONTAINER=$(echo "${DEVBASE_CONTAINERS_REGISTRY}" |
        sed -E 's|^[^:]+://||' | # Remove protocol
        sed -E 's|/.*$||')       # Remove path
    elif [[ -n "${DEVBASE_REGISTRY_URL:-}" ]]; then
      # Remove protocol and path: "https://host:port/path" -> "host:port"
      DEVBASE_REGISTRY_CONTAINER=$(echo "${DEVBASE_REGISTRY_URL}" |
        sed -E 's|^[^:]+://||' | # Remove protocol
        sed -E 's|/.*$||')       # Remove path
    fi
  fi

  # Check custom first, then core
  if [[ -f "${DEVBASE_CUSTOM_TEMPLATES}/registries.conf.template" ]]; then
    template_to_use="${DEVBASE_CUSTOM_TEMPLATES}/registries.conf.template"
    show_progress info "Configuring container registry with custom settings"
  elif [[ -f "${container_templates_dir}/registries.conf.template" ]]; then
    template_to_use="${container_templates_dir}/registries.conf.template"
    show_progress info "Configuring container registry mirror"
  fi

  if [[ -n "$template_to_use" ]] && [[ -f "$template_to_use" ]]; then
    envsubst_preserve_undefined "$template_to_use" "$target_file"
    show_progress success "Container registry configured"
  fi
}

process_custom_templates() {
  [[ -n "${DEVBASE_CUSTOM_TEMPLATES}" ]] && [[ -d "${DEVBASE_CUSTOM_TEMPLATES}" ]] || return 0

  local file_count
  file_count=$(find "${DEVBASE_CUSTOM_TEMPLATES}" -type f -name "*" ! -name "README*" 2>/dev/null | wc -l)

  [[ $file_count -eq 0 ]] && return 0

  for file in "${DEVBASE_CUSTOM_TEMPLATES}"/*; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" == README* ]] && continue

    process_single_custom_file "$file"
  done

  return 0
}
