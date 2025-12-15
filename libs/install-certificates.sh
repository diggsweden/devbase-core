#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Install custom certificates to system trust store and configure Git
# Params: None
# Uses: _DEVBASE_CUSTOM_CERTS (global, optional), validate_custom_dir (function)
# Returns: 0 always
# Side-effects: Copies certs to system, updates trust store, configures Git
install_certificates() {
  validate_custom_dir "_DEVBASE_CUSTOM_CERTS" "Custom certificates directory" || return 0

  local cert_src="${_DEVBASE_CUSTOM_CERTS}"

  local cert_count
  cert_count=$(find "${cert_src}" -maxdepth 1 -name "*.crt" -type f 2>/dev/null | wc -l)
  [[ $cert_count -eq 0 ]] && return 0

  show_progress info "Found $cert_count certificate(s) in custom config"

  local newly_installed=0
  local already_exists=0
  local updated=0
  local skipped=0
  local domains_configured=0

  for cert in "${cert_src}"/*.crt; do
    [[ -f "$cert" ]] || continue

    local cert_name
    cert_name=$(basename "$cert")
    local cert_basename="${cert_name%.crt}"
    local target_cert="/usr/local/share/ca-certificates/${cert_name}"

    # Validate certificate format
    if ! openssl x509 -in "$cert" -noout 2>/dev/null; then
      skipped=$((skipped + 1))
      [[ "$DEVBASE_DEBUG" == "1" ]] && echo "    Invalid certificate format: $cert_name"
      continue
    fi

    # Check if certificate already exists and compare
    if [[ -f "$target_cert" ]]; then
      if cmp -s "$cert" "$target_cert"; then
        already_exists=$((already_exists + 1))
        [[ "$DEVBASE_DEBUG" == "1" ]] && echo "    Already installed: $cert_name"
      else
        sudo cp "$cert" "$target_cert"
        updated=$((updated + 1))
        [[ "$DEVBASE_DEBUG" == "1" ]] && echo "    Updated: $cert_name"
      fi
    else
      sudo cp "$cert" "$target_cert"
      newly_installed=$((newly_installed + 1))
      [[ "$DEVBASE_DEBUG" == "1" ]] && echo "    Newly installed: $cert_name"
    fi

    # Configure Git for this certificate's domain
    local cert_domain=""
    cert_domain=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null |
      grep -oP 'CN\s*=\s*\K[^\s,]+' | head -1 || true)

    if [[ -z "$cert_domain" ]] && [[ "$cert_basename" =~ \. ]]; then
      cert_domain="$cert_basename"
    fi

    if configure_git_certificate "$cert_domain"; then
      domains_configured=$((domains_configured + 1))
    fi
  done

  # Only update system certificates if there were changes
  if [[ $newly_installed -gt 0 ]] || [[ $updated -gt 0 ]]; then
    show_progress info "Updating system trust store..."
    update_system_certificates

    # Build status message based on what happened
    local msg=""
    if [[ $newly_installed -gt 0 ]]; then
      msg="Installed $newly_installed new certificate(s)"
    fi
    if [[ $updated -gt 0 ]]; then
      [[ -n "$msg" ]] && msg="${msg}, updated $updated" || msg="Updated $updated certificate(s)"
    fi
    if [[ $already_exists -gt 0 ]]; then
      [[ -n "$msg" ]] && msg="${msg}, $already_exists unchanged" || msg="$already_exists unchanged"
    fi
    [[ $domains_configured -gt 0 ]] && msg="${msg} (configured $domains_configured Git domain(s))"
    [[ $skipped -gt 0 ]] && msg="${msg} ($skipped invalid skipped)"

    show_progress success "$msg"
  elif [[ $already_exists -gt 0 ]]; then
    show_progress success "All $already_exists certificate(s) already installed (no changes needed)"
  else
    show_progress warning "No valid certificates to install"
  fi
}

# Brief: Configure Git to trust certificate for specific domain
# Params: $1 - cert_domain
# Returns: 0 on success, 1 if invalid domain
# Side-effects: Sets Git global config for domain
configure_git_certificate() {
  local cert_domain="$1"

  validate_not_empty "$cert_domain" "certificate domain" || return 1
  [[ ! "$cert_domain" =~ \. ]] && return 1

  git config --global "http.https://${cert_domain}/.sslCAInfo" /etc/ssl/certs/ca-certificates.crt

  if [[ "$cert_domain" =~ ^[^.]+\.(.+)$ ]]; then
    local base_domain="${BASH_REMATCH[1]}"
    git config --global "http.https://*.${base_domain}/.sslCAInfo" /etc/ssl/certs/ca-certificates.crt
  fi

  return 0
}

# Brief: Update system certificate trust store
# Params: None
# Returns: 0 always
# Side-effects: Rebuilds system cert bundle, configures snap certs
update_system_certificates() {
  if [[ "$DEVBASE_DEBUG" == "1" ]]; then
    sudo update-ca-certificates 2>&1 | sed 's/^/    /'
  else
    # Capture the summary line from update-ca-certificates
    local result
    result=$(sudo update-ca-certificates 2>&1)
    local added=$(echo "$result" | grep -oP '\d+(?= added)' || echo "0")
    local removed=$(echo "$result" | grep -oP '\d+(?= removed)' || echo "0")

    if [[ "$added" != "0" ]] || [[ "$removed" != "0" ]]; then
      echo "    System trust store: $added added, $removed removed"
    fi
  fi

  configure_snap_certificates

  return 0
}
