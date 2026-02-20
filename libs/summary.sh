#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Installation summary generation functions

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

_summary_header() {
  cat <<EOF
DEVBASE INSTALLATION SUMMARY
============================
Installation Date: $(date)
Environment: ${_DEVBASE_ENV:-unknown}
OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
Theme: ${DEVBASE_THEME}
DevBase Version: $(cat "${DEVBASE_CONFIG_DIR}/version" 2>/dev/null || echo "unknown")
$(if is_wsl; then echo "WSL Version: $(get_wsl_version 2>/dev/null || echo "unknown")"; fi)
EOF
}

_summary_system_config() {
  cat <<EOF

SYSTEM CONFIGURATION
====================
User: ${USER:-$(whoami)}
Home: ${HOME:-~}
Shell: ${SHELL:-unknown}
XDG_CONFIG_HOME: ${XDG_CONFIG_HOME:-~/.config}
XDG_DATA_HOME: ${XDG_DATA_HOME:-~/.local/share}
EOF
}

_summary_development_languages() {
  cat <<EOF

DEVELOPMENT LANGUAGES (mise-managed)
====================================
  • Node.js: $(command -v node >/dev/null && node --version | sed 's/^v//' || echo "not found")
  • Python: $(command -v python >/dev/null && python --version 2>&1 | cut -d' ' -f2 || echo "not found")
  • Go: $(command -v go >/dev/null && go version | cut -d' ' -f3 | sed 's/go//' || echo "not found")
  • Ruby: $(command -v ruby >/dev/null && ruby --version | cut -d' ' -f2 || echo "not found")
  • Rust: $(command -v rustc >/dev/null && rustc --version | cut -d' ' -f2 || echo "not found")
  • Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "not found")
  • Maven: $(command -v mvn >/dev/null && mvn --version 2>&1 | head -1 | cut -d' ' -f3 || echo "not found")
  • Gradle: $(command -v gradle >/dev/null && gradle --version 2>&1 | grep Gradle | cut -d' ' -f2 || echo "not found")
EOF
}

_summary_shell_terminal() {
  cat <<EOF

SHELL & TERMINAL
================
  • Fish: $(fish --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Starship: $(starship --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • Zellij: $(command -v zellij >/dev/null && zellij --version | cut -d' ' -f2 || echo "not found")
  • Zellij Autostart: $DEVBASE_ZELLIJ_AUTOSTART
  • Monaspace Nerd Font: $(if is_wsl; then echo "not applicable (WSL)"; elif [[ -d ~/.local/share/fonts/MonaspaceNerdFont ]]; then
    font_count=$(find ~/.local/share/fonts/MonaspaceNerdFont -name "*.ttf" -o -name "*.otf" 2>/dev/null | wc -l)
    if [[ $font_count -gt 0 ]]; then echo "installed ($font_count fonts)"; else echo "not installed"; fi
  else echo "not installed"; fi)
EOF
}

_summary_development_tools() {
  cat <<EOF

DEVELOPMENT TOOLS
=================
  • Git: $(git --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
  • Neovim: $(nvim --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • LazyVim: $([ -d ~/.config/nvim ] && echo "installed" || echo "not installed")
  • VS Code: $(code --version 2>/dev/null | head -1 || echo "not found")
  • Lazygit: $(lazygit --version 2>/dev/null | grep -oP 'version=\K[^,]+' || echo "not found")
  • Ripgrep: $(rg --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "not found")
  • Fd: $(fd --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Fzf: $(fzf --version 2>/dev/null | cut -d' ' -f1 || echo "not found")
  • Eza: $(eza --version 2>/dev/null | head -1 | grep -o 'v[0-9.]*' || echo "not found")
  • Bat: $(bat --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Delta: $(delta --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Jq: $(jq --version 2>/dev/null | sed 's/jq-//' || echo "not found")
  • Yq: $(yq --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
EOF
}

_summary_container_tools() {
  cat <<EOF

CONTAINER TOOLS
===============
  • Podman: $(podman --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Buildah: $(buildah --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
  • Skopeo: $(skopeo --version 2>/dev/null | cut -d' ' -f3 || echo "not found")
EOF
}

_summary_cloud_kubernetes() {
  cat <<EOF

CLOUD & KUBERNETES
==================
  • kubectl: $(kubectl version --client 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "not found")
  • oc: $(oc version --client 2>/dev/null | grep -o '[0-9.]*' | head -1 || echo "not found")
  • k9s: $(k9s version 2>/dev/null | grep Version | cut -d' ' -f2 || echo "not found")
EOF
}

_summary_optional_tools() {
  local intellij_root="${HOME}/.local/share/JetBrains/IntelliJIdea"
  local intellij_version=""
  if [[ -f "${intellij_root}/product-info.json" ]]; then
    intellij_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${intellij_root}/product-info.json" | head -1 | cut -d'"' -f4)
  fi

  local intellij_status="not installed"
  if [[ -d "$intellij_root" ]]; then
    if [[ -n "$intellij_version" ]]; then
      intellij_status="installed (${intellij_version})"
    else
      intellij_status="installed"
    fi
  fi

  cat <<EOF

OPTIONAL TOOLS
==============
  • DBeaver: $([ -f ~/.local/bin/dbeaver ] && echo "installed" || echo "not installed")
  • KeyStore Explorer: $([ -f ~/.local/bin/kse ] && echo "installed" || echo "not installed")
  • IntelliJ IDEA: ${intellij_status}
  • JMC: $(command -v jmc &>/dev/null && echo "installed" || echo "not installed")
EOF
}

_summary_git_config() {
  cat <<EOF

GIT CONFIGURATION
=================
  • Name: $(git config --global user.name 2>/dev/null || echo "not configured")
  • Email: $(git config --global user.email 2>/dev/null || echo "not configured")
  • Default Branch: $(git config --global init.defaultBranch 2>/dev/null || echo "not configured")
  • GPG Sign: $(git config --global commit.gpgsign 2>/dev/null || echo "not configured")
  • SSH Sign: $(git config --global gpg.format 2>/dev/null || echo "not configured")
EOF
}

_summary_ssh_config() {
  local key_type_upper
  key_type_upper=$(echo "${DEVBASE_SSH_KEY_TYPE:-ed25519}" | tr '[:lower:]' '[:upper:]')
  local key_path="${HOME}/.ssh/${DEVBASE_SSH_KEY_NAME:-$(get_default_ssh_key_name)}"

  cat <<EOF

SSH CONFIGURATION
=================
  • Key Type: ${key_type_upper}
  • Key Path: ${key_path}
  • Key Exists: $([ -f "${key_path}" ] && echo "yes" || echo "no")
  • Public Key Exists: $([ -f "${key_path}.pub" ] && echo "yes" || echo "no")
  • SSH Agent: $([ -n "${SSH_AUTH_SOCK:-}" ] && echo "configured" || echo "not configured")
EOF
}

_summary_network_config() {
  cat <<EOF

NETWORK CONFIGURATION
=====================
  • Proxy: $(if [[ -n "${DEVBASE_PROXY_HOST:-}" && -n "${DEVBASE_PROXY_PORT:-}" ]]; then echo "${DEVBASE_PROXY_HOST}:${DEVBASE_PROXY_PORT}"; else echo "not configured"; fi)
  • Registry: $(if [[ -n "${DEVBASE_REGISTRY_HOST:-}" && -n "${DEVBASE_REGISTRY_PORT:-}" ]]; then echo "${DEVBASE_REGISTRY_HOST}:${DEVBASE_REGISTRY_PORT}"; else echo "not configured"; fi)
EOF
}

_summary_mise_activation() {
  cat <<EOF

MISE ACTIVATION
===============
  • Mise Version: $(mise --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
  • Config File: $([ -f ~/.config/mise/config.toml ] && echo "exists" || echo "missing")
  • Activation: Run 'eval "\$(mise activate bash)"' or restart shell
EOF
}

_summary_custom_config() {
  cat <<EOF

CUSTOM CONFIGURATION
====================
  • Custom Dir: $(if [[ -n "${DEVBASE_CUSTOM_DIR:-}" ]]; then echo "${DEVBASE_CUSTOM_DIR}"; else echo "not configured (using defaults)"; fi)
  • Custom Env: $(if [[ -n "${DEVBASE_CUSTOM_ENV:-}" ]]; then echo "loaded"; else echo "not loaded"; fi)
EOF
}

_summary_next_steps() {
  cat <<EOF

NEXT STEPS
==========
1. Restart your shell or run: exec fish
2. Verify installation: ./verify/verify-install-check.sh

For help and documentation: https://github.com/diggsweden/devbase-core
EOF
}

# Brief: Write installation summary to config directory
# Params: None
# Uses: DEVBASE_CONFIG_DIR, _summary_* functions
# Returns: 0 on success, 1 on validation failure
# Side-effects: Creates install-summary.txt in DEVBASE_CONFIG_DIR
write_installation_summary() {
  validate_var_set "DEVBASE_CONFIG_DIR" || return 1

  {
    _summary_header
    _summary_system_config
    _summary_development_languages
    _summary_shell_terminal
    _summary_development_tools
    _summary_container_tools
    _summary_cloud_kubernetes
    _summary_optional_tools
    _summary_git_config
    _summary_ssh_config
    _summary_network_config
    _summary_mise_activation
    _summary_custom_config
    _summary_next_steps
  } >"${DEVBASE_CONFIG_DIR}/install-summary.txt"

  return 0
}
