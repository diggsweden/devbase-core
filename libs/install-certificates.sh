#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # This handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
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

  show_progress info "Installing certificates..."

  local processed=0
  local skipped=0
  local domains_configured=0

  for cert in "${cert_src}"/*.crt; do
    [[ -f "$cert" ]] || continue

    local cert_name
    cert_name=$(basename "$cert")
    local cert_basename="${cert_name%.crt}"

    if ! openssl x509 -in "$cert" -noout 2>/dev/null; then
      skipped=$((skipped + 1))
      continue
    fi

    sudo cp "$cert" "/usr/local/share/ca-certificates/${cert_name}"

    local cert_domain=""
    cert_domain=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null |
      grep -oP 'CN\s*=\s*\K[^\s,]+' | head -1 || true)

    if [[ -z "$cert_domain" ]] && [[ "$cert_basename" =~ \. ]]; then
      cert_domain="$cert_basename"
    fi

    if configure_git_certificate "$cert_domain"; then
      domains_configured=$((domains_configured + 1))
    fi

    processed=$((processed + 1))
  done

  if [[ $processed -gt 0 ]]; then
    update_system_certificates

    local msg="Certificates installed ($processed certs"
    [[ $domains_configured -gt 0 ]] && msg="${msg}, $domains_configured Git domains"
    [[ $skipped -gt 0 ]] && msg="${msg}, $skipped invalid"
    msg="${msg})"
    show_progress success "$msg"
  else
    show_progress warning "No valid certificates found"
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
  sudo update-ca-certificates 2>&1 | sed 's/^/    /'
  configure_snap_certificates

  return 0
}
