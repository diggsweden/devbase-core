#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Setup SSH config includes (user.config and custom.config)
# Params: None
# Uses: _DEVBASE_CUSTOM_SSH (global, optional), HOME (global), validate_custom_file (function)
# Returns: 0 always
# Side-effects: Creates config files, sets permissions
setup_ssh_config_includes() {
  validate_var_set "HOME" || return 1

  chmod 700 ~/.ssh
  chmod 755 ~/.config/ssh

  if validate_custom_dir "_DEVBASE_CUSTOM_SSH" "Custom SSH directory"; then
    for file in "${_DEVBASE_CUSTOM_SSH}"/*; do
      [[ -f "$file" ]] || continue
      
      local filename
      filename=$(basename "$file")
      
      case "$filename" in
        README.md|README*)
          continue
          ;;
        *.config)
          cp "$file" ~/.config/ssh/"$filename"
          chmod 600 ~/.config/ssh/"$filename"
          ;;
        *.append)
          local target_name="${filename%.append}"
          local target_file="${HOME}/.ssh/${target_name}"
          touch "$target_file"
          
          while IFS= read -r line; do
            if [[ -n "$line" ]] && ! grep -qF "$line" "$target_file" 2>/dev/null; then
              echo "$line" >> "$target_file"
            fi
          done < "$file"
          ;;
        *)
          cp "$file" ~/.ssh/"$filename"
          chmod 600 ~/.ssh/"$filename"
          ;;
      esac
    done
  fi

  if [[ ! -f ~/.config/ssh/user.config ]]; then
    cat >~/.config/ssh/user.config <<'EOF'
# Personal SSH Configuration
# This file is NEVER modified by DevBase - safe to edit
#
# You can add new hosts or override settings from custom.config
#
# Example:
# Host personal-server
#   HostName 192.168.1.100
#   User myuser
#   IdentityFile ~/.ssh/id_ed25519_personal
EOF
    chmod 600 ~/.config/ssh/user.config
  fi
}

# Brief: Configure SSH keys and config
# Params: None
# Uses: DEVBASE_SSH_KEY_ACTION, DEVBASE_SSH_PASSPHRASE, DEVBASE_GIT_EMAIL,
#       HOME, XDG_CONFIG_HOME (globals)
# Modifies: DEVBASE_NEW_SSH_KEY (exported if key generated)
# Returns: 0 always
# Side-effects: Generates SSH keys, enables ssh-agent service
configure_ssh() {
  validate_var_set "HOME" || return 1
  validate_var_set "XDG_CONFIG_HOME" || return 1
  validate_var_set "DEVBASE_SSH_KEY_TYPE" || return 1
  validate_var_set "DEVBASE_SSH_KEY_NAME" || return 1

  local ssh_key_path="${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME}"
  local key_generated=false
  local agent_enabled=false
  local passphrase_protected=false

  if [[ "$DEVBASE_SSH_KEY_ACTION" == "new" ]]; then
    validate_var_set "DEVBASE_GIT_EMAIL" || return 1
    show_progress info "Configuring SSH..."

    if [[ -f "$ssh_key_path" ]]; then
      local backup_name
      backup_name="${ssh_key_path}.backup.$(date +%Y%m%d_%H%M%S)"
      mv "$ssh_key_path" "$backup_name"
      mv "${ssh_key_path}.pub" "${backup_name}.pub"
    fi

    # Generate SSH key based on type
    case "${DEVBASE_SSH_KEY_TYPE}" in
    ecdsa)
      # Generate ECDSA key with P-521 curve
      if [[ -n "${DEVBASE_SSH_PASSPHRASE:-}" ]]; then
        ssh-keygen -t ecdsa -b 521 -C "${DEVBASE_GIT_EMAIL}" -f "$ssh_key_path" -N "${DEVBASE_SSH_PASSPHRASE}" -q
        passphrase_protected=true
      else
        ssh-keygen -t ecdsa -b 521 -C "${DEVBASE_GIT_EMAIL}" -f "$ssh_key_path" -N "" -q
      fi
      ;;

    ed25519 | ed25519-sk | ecdsa-sk)
      # Generate key without bit size parameter
      if [[ -n "${DEVBASE_SSH_PASSPHRASE:-}" ]]; then
        ssh-keygen -t "${DEVBASE_SSH_KEY_TYPE}" -C "${DEVBASE_GIT_EMAIL}" -f "$ssh_key_path" -N "${DEVBASE_SSH_PASSPHRASE}" -q
        passphrase_protected=true
      else
        ssh-keygen -t "${DEVBASE_SSH_KEY_TYPE}" -C "${DEVBASE_GIT_EMAIL}" -f "$ssh_key_path" -N "" -q
      fi
      ;;

    *)
      show_progress error "Unknown SSH key type '${DEVBASE_SSH_KEY_TYPE}'"
      show_progress info "Supported types: ed25519, ecdsa, ed25519-sk, ecdsa-sk"
      return 1
      ;;
    esac

    key_generated=true
    export DEVBASE_NEW_SSH_KEY="${ssh_key_path}.pub"
  elif [[ "${DEVBASE_SSH_KEY_ACTION}" == "skip" ]]; then
    return 0
  fi

  setup_ssh_config_includes

  if [[ -f "${HOME}/.ssh/config" ]]; then
    chmod 600 "${HOME}/.ssh/config"
  else
    show_progress warning "SSH config not found - template may not have been copied from dot/.ssh/config"
  fi

  if [[ -f "${XDG_CONFIG_HOME}/systemd/user/ssh-agent.service" ]]; then
    if enable_user_service "ssh-agent.service" &>/dev/null; then
      agent_enabled=true
    fi
  fi

  if [[ "$key_generated" == true ]]; then
    local key_type_upper
    key_type_upper=$(echo "${DEVBASE_SSH_KEY_TYPE}" | tr '[:lower:]' '[:upper:]')
    local msg="SSH configured (${key_type_upper} key at ${ssh_key_path}"
    [[ "$passphrase_protected" == true ]] && msg="${msg}, passphrase protected"
    [[ "$agent_enabled" == true ]] && msg="${msg}, agent enabled"
    msg="${msg})"
    show_progress success "$msg"
  fi

  return 0
}

# Brief: Configure Git user name and email
# Params: None
# Uses: DEVBASE_GIT_AUTHOR, DEVBASE_GIT_EMAIL, USER, hostname (globals)
# Returns: Echoes "true" if configured, "existing" if unchanged
# Side-effects: Sets global git config
configure_git_user() {
  validate_var_set "USER" || return 1

  local existing_name
  existing_name=$(git config --global user.name 2>/dev/null)
  local existing_email
  existing_email=$(git config --global user.email 2>/dev/null)

  # DEVBASE_GIT_AUTHOR and DEVBASE_GIT_EMAIL are always set from GIT_NAME/GIT_EMAIL
  # (which have defaults in setup.sh IMPORT section)
  if [[ "${DEVBASE_GIT_AUTHOR}" != "$existing_name" ]] || [[ "${DEVBASE_GIT_EMAIL}" != "$existing_email" ]]; then
    git config --global user.name "${DEVBASE_GIT_AUTHOR}"
    git config --global user.email "${DEVBASE_GIT_EMAIL}"
    echo "true"
  else
    echo "existing"
  fi
}

# Brief: Configure Git to use proxy for HTTP(S) operations
# Params: None
# Uses: DEVBASE_PROXY_HOST, DEVBASE_PROXY_PORT, DEVBASE_NO_PROXY_DOMAINS (globals)
# Returns: 0 if configured, 1 if no proxy set
# Side-effects: Sets global git config for proxy
configure_git_proxy() {
  [[ -z "${DEVBASE_PROXY_HOST:-}" || -z "${DEVBASE_PROXY_PORT:-}" ]] && return 1

  local proxy_url="http://${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"

  git config --global --unset-all http.proxy 2>/dev/null || true
  git config --global --unset-all https.proxy 2>/dev/null || true

  git config --global http.proxy "${proxy_url}"
  git config --global https.proxy "${proxy_url}"

  if [[ -n "${DEVBASE_NO_PROXY_DOMAINS:-}" ]]; then
    IFS=',' read -ra NO_PROXY_ARRAY <<<"${DEVBASE_NO_PROXY_DOMAINS}"
    for domain in "${NO_PROXY_ARRAY[@]}"; do
      # Trim whitespace
      domain=$(echo "$domain" | xargs)
      [[ -z "$domain" ]] && continue

      # Convert .domain.com to *.domain.com for git config
      if [[ "$domain" == .* ]] && [[ "$domain" != *"*"* ]]; then
        domain="*${domain}"
      fi

      # Set empty proxy for this domain pattern
      git config --global "http.https://${domain}/.proxy" ""
    done
  fi

  return 0
}

# Brief: Configure Git commit signing with SSH key
# Params: None
# Uses: DEVBASE_GIT_EMAIL, HOME (globals)
# Returns: 0 if configured, 1 if SSH key doesn't exist
# Side-effects: Sets global git config, creates allowed_signers file
configure_git_signing() {
  validate_var_set "HOME" || return 1
  validate_var_set "DEVBASE_GIT_EMAIL" || return 1
  validate_var_set "DEVBASE_SSH_KEY_NAME" || return 1

  local git_signing_key="${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME}.pub"

  [[ ! -f "$git_signing_key" ]] && return 1

  git config --global gpg.format ssh
  git config --global user.signingkey "$git_signing_key"

  local allowed_signers="${HOME}/.ssh/allowed_signers"
  local git_pub_signingkey
  git_pub_signingkey=$(cat "$git_signing_key")
  echo "${DEVBASE_GIT_EMAIL} ${git_pub_signingkey}" >"$allowed_signers"
  git config --global gpg.ssh.allowedSignersFile "$allowed_signers"

  return 0
}

# Brief: Configure Git (user, proxy, signing)
# Params: None
# Uses: HOME (global)
# Returns: 0 always
# Side-effects: Calls configure_git_user, configure_git_proxy, configure_git_signing
configure_git() {
  validate_var_set "HOME" || return 1

  show_progress info "Configuring Git..."

  [[ ! -f "${HOME}/.gitconfig" ]] && touch "${HOME}/.gitconfig"

  local user_status
  user_status=$(configure_git_user)

  local proxy_configured=false
  configure_git_proxy && proxy_configured=true

  local signing_configured=false
  configure_git_signing && signing_configured=true

  local msg="Git configured ("
  local details=()
  [[ "$user_status" != "false" ]] && details+=("user: ${DEVBASE_GIT_EMAIL}")
  [[ "$proxy_configured" == true ]] && details+=("proxy: enabled")
  [[ "$signing_configured" == true ]] && details+=("SSH signing: enabled")

  local IFS=", "
  msg="${msg}${details[*]})"

  show_progress success "$msg"
  return 0
}
