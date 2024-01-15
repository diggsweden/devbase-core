#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
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
