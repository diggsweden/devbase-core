#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Validate that a required parameter is not empty
# Usage: validate_not_empty "$param" "parameter_name"
validate_not_empty() {
  local value="$1"
  local name="${2:-parameter}"

  if [[ -z "$value" ]]; then
    show_progress error "${name} is required but was empty"
    return 1
  fi
  return 0
}

# Brief: Validate that a file exists
# Params: $1 - filepath to check, $2 - description (optional, default: "file")
# Uses: show_progress (from ui-helpers)
# Returns: 0 if file exists, 1 if not found
validate_file_exists() {
  local filepath="$1"
  local description="${2:-file}"

  if [[ ! -f "$filepath" ]]; then
    show_progress error "${description} not found: ${filepath}"
    return 1
  fi
  return 0
}

# Validate that a directory exists
# Usage: validate_dir_exists "$dirpath" "description"
validate_dir_exists() {
  local dirpath="$1"
  local description="${2:-directory}"

  if [[ ! -d "$dirpath" ]]; then
    show_progress error "${description} not found: ${dirpath}"
    return 1
  fi
  return 0
}

# Brief: Validate URL format starts with http:// or https://
# Params: $1 - url to validate
# Uses: show_progress (from ui-helpers)
# Returns: 0 if valid URL format, 1 if invalid
validate_url() {
  local url="$1"

  if [[ ! "$url" =~ ^https?:// ]]; then
    show_progress error "Invalid URL format: ${url}"
    return 1
  fi
  return 0
}

# Brief: Validate that an environment variable is set and not empty
# Params: $1 - variable name to check (string, not the value)
# Uses: show_progress (from ui-helpers)
# Returns: 0 if variable is set and not empty, 1 if unset or empty
validate_var_set() {
  local varname="$1"

  if [[ -z "${!varname:-}" ]]; then
    show_progress error "Required variable ${varname} is not set"
    return 1
  fi
  return 0
}

# Brief: Validate custom directory path is set and exists
# Params: $1 - variable name containing directory path
#         $2 - description (optional, default: "custom directory")
# Uses: show_progress (from ui-helpers)
# Returns: 0 if variable is set and directory exists, 1 otherwise (silently)
# Notes: Returns 1 silently if variable is empty (custom dirs are optional)
validate_custom_dir() {
  local varname="$1"
  local description="${2:-custom directory}"

  local value="${!varname}"

  # Not set or empty - silently return (custom directories are optional)
  if [[ -z "$value" ]]; then
    return 1
  fi

  # Set but directory doesn't exist - this is an error
  if [[ ! -d "$value" ]]; then
    show_progress error "${description} does not exist: ${value}"
    return 1
  fi

  return 0
}

# Brief: Validate custom file exists (only if parent directory is set)
# Params: $1 - variable name containing parent directory path
#         $2 - filename to check within that directory
#         $3 - description (optional, default: "custom file")
# Returns: 0 if directory is set and file exists, 1 otherwise (silently)
# Notes: Returns 1 silently if directory not set or file doesn't exist
validate_custom_file() {
  local dir_var="$1"
  local filename="$2"
  local description="${3:-custom file}"

  local dir="${!dir_var}"

  # Directory not set - silently return (custom directories are optional)
  if [[ -z "$dir" ]]; then
    return 1
  fi

  local filepath="$dir/$filename"

  # File doesn't exist - silently return (custom files are optional)
  if [[ ! -f "$filepath" ]]; then
    return 1
  fi

  return 0
}

# Brief: Validate optional directory variable (set and exists, or empty)
# Params: $1 - variable name containing directory path
#         $2 - description (optional, default: "directory")
# Uses: show_progress (from ui-helpers)
# Returns: 0 if variable is set and directory exists, 1 if empty or doesn't exist
# Notes: Returns 1 silently if variable is empty (optional directory)
#        Shows error if variable is set but directory doesn't exist
validate_optional_dir() {
  local varname="$1"
  local description="${2:-directory}"

  local value="${!varname}"

  # Not set or empty - silently return (optional directory)
  if [[ -z "$value" ]]; then
    return 1
  fi

  # Set but directory doesn't exist - this is an error
  if [[ ! -d "$value" ]]; then
    show_progress error "${description} does not exist: ${value}"
    return 1
  fi

  return 0
}

# Brief: Validate hostname format (no spaces, no shell metacharacters)
# Params: $1 - value to validate, $2 - variable name (for error messages)
# Returns: 0 if valid, 1 if invalid
validate_hostname() {
  local value="$1"
  local name="${2:-hostname}"

  if [[ -z "$value" ]]; then
    return 0 # Empty is OK (optional)
  fi

  # Reject shell metacharacters and whitespace
  if [[ "$value" =~ [[:space:]\;\|\&\$\`\(\)\{\}\<\>\!\#] ]]; then
    show_progress error "${name} contains invalid characters: ${value}"
    return 1
  fi
  return 0
}

# Brief: Validate port number (1-65535, digits only)
# Params: $1 - value to validate, $2 - variable name (for error messages)
# Returns: 0 if valid, 1 if invalid
validate_port() {
  local value="$1"
  local name="${2:-port}"

  if [[ -z "$value" ]]; then
    return 0 # Empty is OK (optional)
  fi

  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]] || [[ "$value" -gt 65535 ]]; then
    show_progress error "${name} must be a number between 1-65535, got: ${value}"
    return 1
  fi
  return 0
}

# Brief: Validate email format (basic: must contain @, no shell metacharacters)
# Params: $1 - value to validate, $2 - variable name (for error messages)
# Returns: 0 if valid, 1 if invalid
validate_email() {
  local value="$1"
  local name="${2:-email}"

  if [[ -z "$value" ]]; then
    return 0
  fi

  if [[ "$value" =~ [[:space:]\;\|\&\$\`\(\)\{\}\<\>\!] ]]; then
    show_progress error "${name} contains invalid characters: ${value}"
    return 1
  fi

  if [[ ! "$value" =~ @ ]]; then
    show_progress warning "${name} does not contain @: ${value}"
  fi
  return 0
}

# Brief: Validate value contains no shell metacharacters (safe for use in config files)
# Params: $1 - value to validate, $2 - variable name (for error messages)
# Returns: 0 if valid, 1 if invalid
validate_safe_value() {
  local value="$1"
  local name="${2:-value}"

  if [[ -z "$value" ]]; then
    return 0
  fi

  if [[ "$value" =~ [\;\|\&\$\`\<\>] ]]; then
    show_progress error "${name} contains shell metacharacters: ${value}"
    return 1
  fi
  return 0
}

# Brief: Validate that template variables are set in environment
# Params: $1 - template_file (for error messages)
#         $2 - vars_to_check (space-separated list like "$VAR1 $VAR2")
# Uses: DEVBASE_REQUIRED_TEMPLATE_VARS, DEVBASE_OPTIONAL_TEMPLATE_VARS, DEVBASE_RUNTIME_TEMPLATE_VARS, show_progress
# Returns: 0 if all required vars are set, 1 if any required var is missing
# Side-effects: Prints info for missing optional vars, warnings for unknown vars, errors for missing required vars
validate_template_variables() {
  local template_file="$1"
  local vars_to_check="$2"

  # Define required variables (must be set - these are actually used in templates)
  local -a DEVBASE_REQUIRED_TEMPLATE_VARS=(
    "HOME"
    "EDITOR"
    "VISUAL"
    "XDG_CONFIG_HOME"
    "DEVBASE_THEME"
    "DEVBASE_ZELLIJ_AUTOSTART"
    "BAT_THEME"
    "BTOP_THEME"
    "DELTA_SYNTAX_THEME"
    "DELTA_FEATURES"
    "DELTA_DARK"
    "ZELLIJ_THEME"
    "ZELLIJ_COPY_COMMAND"
    "THEME_BACKGROUND"
    "LAZYGIT_LIGHT_THEME"
    "VIFM_COLORSCHEME"
    "K9S_SKIN"
  )

  # Define optional variables (warnings only if missing - features are disabled if not set)
  local -a DEVBASE_OPTIONAL_TEMPLATE_VARS=(
    "DEVBASE_CUSTOM_CERTS"
    "DEVBASE_PROXY_HOST"
    "DEVBASE_PROXY_PORT"
    "DEVBASE_NO_PROXY_DOMAINS"
    "DEVBASE_REGISTRY_HOST"
    "DEVBASE_REGISTRY_PORT"
    "DEVBASE_REGISTRY_URL"
    "DEVBASE_REGISTRY_CONTAINER"
    "DEVBASE_PYPI_REGISTRY"
  )

  # Define runtime variables (not replaced by envsubst, evaluated at runtime by shell)
  # These are variables that appear in templates but should remain as literal $VAR syntax
  local -a DEVBASE_RUNTIME_TEMPLATE_VARS=(
    "XDG_RUNTIME_DIR"
    "USER_UID"
  )

  local missing_required=()
  local missing_optional=()
  local unknown_vars=()

  # Check each variable found in template
  for var in $vars_to_check; do
    local var_name="${var#\$}" # Remove $ prefix

    # Skip if variable is actually set (has non-empty value)
    if [[ -n "${!var_name:-}" ]]; then
      continue
    fi

    # Variable is NOT set - categorize it
    local is_required=false
    local is_optional=false
    local is_runtime=false

    for req_var in "${DEVBASE_REQUIRED_TEMPLATE_VARS[@]}"; do
      if [[ "$var_name" == "$req_var" ]]; then
        is_required=true
        break
      fi
    done

    if [[ "$is_required" == false ]]; then
      for opt_var in "${DEVBASE_OPTIONAL_TEMPLATE_VARS[@]}"; do
        if [[ "$var_name" == "$opt_var" ]]; then
          is_optional=true
          break
        fi
      done
    fi

    if [[ "$is_required" == false ]] && [[ "$is_optional" == false ]]; then
      for runtime_var in "${DEVBASE_RUNTIME_TEMPLATE_VARS[@]}"; do
        if [[ "$var_name" == "$runtime_var" ]]; then
          is_runtime=true
          break
        fi
      done
    fi

    if [[ "$is_required" == true ]]; then
      missing_required+=("$var_name")
    elif [[ "$is_optional" == true ]]; then
      missing_optional+=("$var_name")
    elif [[ "$is_runtime" == false ]]; then
      # Only add to unknown if it's not a runtime variable
      unknown_vars+=("$var_name")
    fi
  done

  # Report unknown variables (not in either list)
  if [[ ${#unknown_vars[@]} -gt 0 ]]; then
    for var in "${unknown_vars[@]}"; do
      show_progress warning "Unknown variable in template $(basename "$template_file"): $var"
    done
  fi

  # Report missing required variables (ERROR - fail)
  if [[ ${#missing_required[@]} -gt 0 ]]; then
    show_progress error "Template processing failed for $(basename "$template_file"): Required variables not set"
    for var in "${missing_required[@]}"; do
      printf "      Missing: %s\n" "$var"
    done
    return 1
  fi

  return 0
}
