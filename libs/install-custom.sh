#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Verify JMC_DOWNLOAD is set (should be set earlier in the process)
if [[ -z "${JMC_DOWNLOAD:-}" ]]; then
  JMC_DOWNLOAD="https://download.oracle.com/java/GA"
fi

# Brief: Fetch VS Code package SHA256 checksum from official API
# Params: $1 - version (e.g. "1.85.1"), $2 - platform (default: "linux-deb-x64")
# Uses: command_exists, validate_not_empty (functions)
# Returns: 0 with checksum on stdout if found, 1 if jq missing or checksum not found
# Side-effects: Makes curl request to code.visualstudio.com
get_vscode_checksum() {
  local version="$1"
  local platform="${2:-linux-deb-x64}"

  validate_not_empty "$version" "VS Code version" || return 1

  if ! command_exists jq; then
    return 1
  fi

  local sha_api="https://code.visualstudio.com/sha"
  local checksum
  checksum=$(curl -fsSL "$sha_api" 2>/dev/null |
    jq -r --arg ver "$version" --arg plat "$platform" \
      '.products[] | select(.productVersion == $ver and .platform.os == $plat and .build == "stable") | .sha256hash' 2>/dev/null)

  if [[ -n "$checksum" ]] && [[ "$checksum" != "null" ]]; then
    echo "$checksum"
    return 0
  fi

  return 1
}

# Brief: Fetch OpenShift CLI package SHA256 checksum from official mirror
# Params: $1 - version (e.g. "4.15.33")
# Uses: validate_not_empty (function)
# Returns: 0 with checksum on stdout if found, 1 if not found
# Side-effects: Makes curl request to mirror.openshift.com
get_oc_checksum() {
  local version="$1"

  validate_not_empty "$version" "OpenShift version" || return 1

  local checksum_url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${version}/sha256sum.txt"
  local checksum

  # Download checksum file and extract the checksum for openshift-client-linux tarball
  if checksum=$(curl -fsSL "$checksum_url" 2>/dev/null | grep "openshift-client-linux-${version}.tar.gz" | awk '{print $1}' 2>/dev/null); then
    if [[ -n "$checksum" ]]; then
      echo "$checksum"
      return 0
    fi
  fi

  return 1
}

# Brief: Install LazyVim Neovim configuration with theme integration
# Params: None
# Uses: XDG_CONFIG_HOME, DEVBASE_THEME, DEVBASE_DOT, TOOL_VERSIONS, validate_var_set, show_progress, envsubst_preserve_undefined (globals/functions)
# Returns: 0 on success, 1 on failure
# Side-effects: Clones LazyVim repo, backs up existing nvim config, configures colorscheme
install_lazyvim() {
  validate_var_set "XDG_CONFIG_HOME" || return 1
  validate_var_set "DEVBASE_THEME" || return 1
  validate_var_set "DEVBASE_DOT" || return 1

  if [[ "${DEVBASE_INSTALL_LAZYVIM:-true}" != "true" ]]; then
    show_progress info "LazyVim installation skipped by user preference"
    return 0
  fi

  show_progress info "Installing LazyVim..."

  local nvim_config="${XDG_CONFIG_HOME}/nvim"
  local backup_dir
  backup_dir="${XDG_CONFIG_HOME}/nvim.bak.$(date +%Y%m%d_%H%M%S)"
  local lazyvim_version="${TOOL_VERSIONS[lazyvim_starter]:-main}"

  if [[ -d "$nvim_config" ]] && [[ ! -L "$nvim_config" ]]; then
    show_progress info "Backing up existing nvim config to $backup_dir"
    mv "$nvim_config" "$backup_dir"
  fi

  if ! command -v git &>/dev/null; then
    show_progress error "git not found, cannot install LazyVim"
    return 1
  fi

  show_progress info "Cloning LazyVim starter (version: $lazyvim_version)..."
  if git clone https://github.com/LazyVim/starter "$nvim_config"; then
    cd "$nvim_config" || return 1

    if [[ "$lazyvim_version" != "main" ]]; then
      git checkout "$lazyvim_version" 2>/dev/null || {
        show_progress warning "Failed to checkout $lazyvim_version, using main"
      }
    fi

    rm -rf .git
    cd - >/dev/null || return
    show_progress success "LazyVim starter installed ($lazyvim_version)"
  else
    show_progress error "Failed to clone LazyVim starter"
    return 1
  fi

  local theme_background="dark"
  if [[ "${DEVBASE_THEME}" == "everforest-light" ]]; then
    theme_background="light"
  fi

  # shellcheck disable=SC2153 # DEVBASE_DOT is exported in setup.sh
  local colorscheme_template="${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua.template"
  local colorscheme_target="$nvim_config/lua/plugins/colorscheme.lua"

  if [[ -f "$colorscheme_template" ]]; then
    mkdir -p "$(dirname "$colorscheme_target")"
    THEME_BACKGROUND="$theme_background" envsubst_preserve_undefined "$colorscheme_template" "$colorscheme_target"
    show_progress success "LazyVim colorscheme configured (${DEVBASE_THEME})"
  else
    show_progress warning "Colorscheme template not found"
  fi

  return 0
}

# Brief: Install Oracle JDK Mission Control (JMC) for Java profiling
# Params: None
# Uses: _DEVBASE_TEMP, XDG_DATA_HOME, XDG_BIN_HOME, TOOL_VERSIONS, JMC_DOWNLOAD, validate_var_set, command_exists, show_progress, retry_command, download_file, backup_if_exists (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and extracts JMC, creates symlink in XDG_BIN_HOME
install_jmc() {
  validate_var_set "_DEVBASE_TEMP" || return 1
  validate_var_set "XDG_DATA_HOME" || return 1
  validate_var_set "XDG_BIN_HOME" || return 1

  if [[ -n "${TOOL_VERSIONS[jdk_mission_control]:-}" ]] && [[ "${DEVBASE_INSTALL_JMC:-no}" == "yes" ]]; then
    if command_exists jmc; then
      show_progress success "JMC already installed"
      return 0
    else
      show_progress info "Installing JDK Mission Control..."
      local jmc_version="${TOOL_VERSIONS[jdk_mission_control]}"
      local jmc_url="${JMC_DOWNLOAD:-https://download.oracle.com/java/GA}/jmc/${jmc_version}/jmc-${jmc_version}_linux-x64.tar.gz"
      local jmc_tar="${_DEVBASE_TEMP}/jmc.tar.gz"

      # Check cache first if DEVBASE_DEB_CACHE is set (reusing same cache dir for all binaries)
      if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
        local cached_tar="${DEVBASE_DEB_CACHE}/jmc-${jmc_version}.tar.gz"
        if [[ -f "$cached_tar" ]]; then
          show_progress info "Using cached JMC package"
          cp "$cached_tar" "$jmc_tar"
        elif retry_command download_file "$jmc_url" "$jmc_tar"; then
          mkdir -p "${DEVBASE_DEB_CACHE}"
          cp "$jmc_tar" "$cached_tar"
        else
          show_progress warning "JMC download failed - skipping"
          return 0
        fi
      elif ! retry_command download_file "$jmc_url" "$jmc_tar"; then
        show_progress warning "JMC download failed - skipping"
        return 0
      fi

      if [[ -f "$jmc_tar" ]]; then
        tar -C "${_DEVBASE_TEMP}" -xzf "$jmc_tar"
        backup_if_exists "${XDG_DATA_HOME}/JDK Mission Control" "jmc-old"

        mv -f "${_DEVBASE_TEMP}/jmc-${jmc_version}_linux-x64/JDK Mission Control/" "${XDG_DATA_HOME}/"
        ln -sf "${XDG_DATA_HOME}/JDK Mission Control/jmc" "${XDG_BIN_HOME}/jmc"
        show_progress success "JDK Mission Control installed"
      else
        show_progress warning "JMC download failed - skipping"
      fi
    fi
  fi
}

# Brief: Install OpenShift CLI (oc) and kubectl from official mirror
# Params: None
# Uses: _DEVBASE_TEMP, XDG_BIN_HOME, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and extracts oc/kubectl to XDG_BIN_HOME
install_oc_kubectl() {
  validate_var_set "_DEVBASE_TEMP" || return 1
  validate_var_set "XDG_BIN_HOME" || return 1

  if [[ -z "${TOOL_VERSIONS[oc]:-}" ]]; then
    return 0
  fi

  if command_exists oc && command_exists kubectl; then
    show_progress success "OpenShift CLI (oc) and kubectl already installed"
    return 0
  fi

  show_progress info "Installing OpenShift CLI (oc) and kubectl..."
  local oc_version="${TOOL_VERSIONS[oc]}"
  local oc_url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${oc_version}/openshift-client-linux.tar.gz"
  local oc_tar="${_DEVBASE_TEMP}/openshift-client.tar.gz"

  # Get expected checksum using helper function
  local expected_checksum=""
  if ! expected_checksum=$(get_oc_checksum "$oc_version"); then
    show_progress warning "Could not fetch OpenShift CLI checksum"
    expected_checksum=""
  fi

  if retry_command download_file "$oc_url" "$oc_tar" "" "$expected_checksum"; then
    tar -C "${_DEVBASE_TEMP}" -xzf "$oc_tar"

    if [[ -f "${_DEVBASE_TEMP}/oc" ]]; then
      mv -f "${_DEVBASE_TEMP}/oc" "${XDG_BIN_HOME}/oc"
      chmod +x "${XDG_BIN_HOME}/oc"
      show_progress success "OpenShift CLI (oc) installed"
    fi

    if [[ -f "${_DEVBASE_TEMP}/kubectl" ]]; then
      mv -f "${_DEVBASE_TEMP}/kubectl" "${XDG_BIN_HOME}/kubectl"
      chmod +x "${XDG_BIN_HOME}/kubectl"
      show_progress success "kubectl installed"
    fi
  else
    # Check if failure was due to checksum mismatch (security issue) vs download failure
    if [[ -n "$expected_checksum" ]] && [[ ! -f "$oc_tar" ]]; then
      show_progress error "OpenShift CLI download/verification FAILED - SECURITY RISK"
      show_progress warning "Possible causes: MITM attack, corrupted mirror, or network issue"
      show_progress warning "Skipping OpenShift CLI installation for safety"
    else
      show_progress warning "OpenShift CLI download failed - skipping"
    fi
  fi
}

# Brief: Install DBeaver Community Edition database tool
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and installs DBeaver .deb package
install_dbeaver() {
  validate_var_set "_DEVBASE_TEMP" || return 1

  if [[ -z "${TOOL_VERSIONS[dbeaver]:-}" ]]; then
    return 0
  fi

  if command_exists dbeaver; then
    show_progress success "DBeaver already installed"
    return 0
  fi

  show_progress info "Installing DBeaver..."
  local dbeaver_version="${TOOL_VERSIONS[dbeaver]}"
  local dbeaver_url="https://github.com/dbeaver/dbeaver/releases/download/${dbeaver_version}/dbeaver-ce_${dbeaver_version}_amd64.deb"
  local dbeaver_deb="${_DEVBASE_TEMP}/dbeaver.deb"

  # Check cache first if DEVBASE_DEB_CACHE is set
  if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
    local cached_deb="${DEVBASE_DEB_CACHE}/dbeaver-${dbeaver_version}.deb"
    if [[ -f "$cached_deb" ]]; then
      show_progress info "Using cached DBeaver package"
      cp "$cached_deb" "$dbeaver_deb"
    elif retry_command download_file "$dbeaver_url" "$dbeaver_deb"; then
      mkdir -p "${DEVBASE_DEB_CACHE}"
      cp "$dbeaver_deb" "$cached_deb"
    else
      show_progress warning "DBeaver download failed - skipping"
      return 0
    fi
  elif ! retry_command download_file "$dbeaver_url" "$dbeaver_deb"; then
    show_progress warning "DBeaver download failed - skipping"
    return 0
  fi

  if [[ -f "$dbeaver_deb" ]]; then
    if sudo dpkg -i "$dbeaver_deb"; then
      show_progress success "DBeaver installed"
    else
      show_progress warning "DBeaver installation failed - trying to fix dependencies"
      sudo apt-get install -f -y -q
      show_progress success "DBeaver installed (with dependency fixes)"
    fi
  else
    show_progress warning "DBeaver download failed - skipping"
  fi
}

# Brief: Install KeyStore Explorer for Java keystore management
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and installs KeyStore Explorer .deb package
install_keystore_explorer() {
  validate_var_set "_DEVBASE_TEMP" || return 1

  if [[ -z "${TOOL_VERSIONS[keystore_explorer]:-}" ]]; then
    return 0
  fi

  if command_exists kse; then
    show_progress success "KeyStore Explorer already installed"
    return 0
  fi

  show_progress info "Installing KeyStore Explorer..."
  local kse_version="${TOOL_VERSIONS[keystore_explorer]}"
  local kse_url="https://github.com/kaikramer/keystore-explorer/releases/download/${kse_version}/kse_${kse_version#v}_all.deb"
  local kse_deb="${_DEVBASE_TEMP}/keystore-explorer.deb"

  # Check cache first if DEVBASE_DEB_CACHE is set
  if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
    local cached_deb="${DEVBASE_DEB_CACHE}/kse-${kse_version}.deb"
    if [[ -f "$cached_deb" ]]; then
      show_progress info "Using cached KeyStore Explorer package"
      cp "$cached_deb" "$kse_deb"
    elif retry_command download_file "$kse_url" "$kse_deb"; then
      mkdir -p "${DEVBASE_DEB_CACHE}"
      cp "$kse_deb" "$cached_deb"
    else
      show_progress warning "KeyStore Explorer download failed - skipping"
      return 0
    fi
  elif ! retry_command download_file "$kse_url" "$kse_deb"; then
    show_progress warning "KeyStore Explorer download failed - skipping"
    return 0
  fi

  if [[ -f "$kse_deb" ]]; then
    if sudo dpkg -i "$kse_deb"; then
      show_progress success "KeyStore Explorer installed"
    else
      show_progress warning "KeyStore Explorer installation failed - trying to fix dependencies"
      sudo apt-get install -f -y -q
      show_progress success "KeyStore Explorer installed (with dependency fixes)"
    fi
  else
    show_progress warning "KeyStore Explorer download failed - skipping"
  fi
}

# Brief: Install k3s lightweight Kubernetes distribution
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads and runs k3s installer script
install_k3s() {
  validate_var_set "_DEVBASE_TEMP" || return 1

  if command -v k3s &>/dev/null; then
    show_progress info "k3s already installed - skipping"
    return 0
  fi

  show_progress info "Installing k3s..."
  local k3s_version="${TOOL_VERSIONS[k3s]}"
  local install_url="https://raw.githubusercontent.com/k3s-io/k3s/${k3s_version}/install.sh"
  local install_script="${_DEVBASE_TEMP}/k3s-install.sh"

  if retry_command download_file "$install_url" "$install_script"; then
    chmod +x "$install_script"
    if INSTALL_K3S_VERSION="$k3s_version" sh "$install_script" &>/dev/null; then
      show_progress success "k3s installed and started ($k3s_version)"
    else
      show_progress warning "k3s installation failed - skipping"
      return 1
    fi
  else
    show_progress warning "k3s installer download failed - skipping"
    return 1
  fi
}

# Brief: Install Fisher plugin manager for Fish shell with fzf.fish
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress (globals/functions)
# Returns: 0 on success, 1 on failure
# Side-effects: Clones Fisher repo, installs Fisher and fzf.fish plugin
install_fisher() {
  validate_var_set "_DEVBASE_TEMP" || return 1

  show_progress info "Installing Fisher (Fish plugin manager)..."

  if ! command_exists fish; then
    show_progress error "Fish shell not found - cannot install Fisher"
    return 1
  fi

  # Check if Fisher is already installed
  if fish -c "type -q fisher" 2>/dev/null; then
    show_progress success "Fisher already installed"
    return 0
  fi

  # Install Fisher from versioned release
  local fisher_version="${TOOL_VERSIONS[fisher]}"
  local fisher_dir="${_DEVBASE_TEMP}/fisher"

  if git clone --depth 1 --branch "${fisher_version}" https://github.com/jorgebucaran/fisher.git "$fisher_dir"; then
    if fish -c "source $fisher_dir/functions/fisher.fish && fisher install jorgebucaran/fisher"; then
      show_progress success "Fisher installed ($fisher_version)"

      # Install fzf.fish plugin
      show_progress info "Installing fzf.fish plugin..."
      if fish -c "fisher install PatrickF1/fzf.fish"; then
        show_progress success "fzf.fish plugin installed (Ctrl+R for history, Ctrl+Alt+F for files)"
      else
        show_progress warning "fzf.fish plugin installation failed"
        return 1
      fi
    else
      show_progress error "Fisher installation failed"
      return 1
    fi
  else
    show_progress error "Failed to clone Fisher repository"
    return 1
  fi

  return 0
}

# Brief: Install Visual Studio Code (native Linux only, skips WSL)
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, is_wsl, command_exists, show_progress, get_vscode_checksum, retry_command, download_file (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads and installs VS Code .deb package with checksum verification
install_vscode() {
  validate_var_set "_DEVBASE_TEMP" || return 1

  # Skip VS Code installation on WSL - it should be installed on Windows
  if is_wsl; then
    show_progress info "[WSL-specific] Skipping VS Code installation on WSL (install from Windows)"
    return 0
  fi

  if command_exists code; then
    show_progress success "VS Code already installed"
    return 0
  fi

  if [[ -z "${TOOL_VERSIONS[vscode]:-}" ]]; then
    show_progress info "VS Code version not specified - skipping"
    return 0
  fi

  show_progress info "Installing VS Code..."
  local version="${TOOL_VERSIONS[vscode]}"
  local vscode_url="https://update.code.visualstudio.com/${version}/linux-deb-x64/stable"
  local vscode_deb="${_DEVBASE_TEMP}/vscode.deb"

  local vscode_checksum
  if ! vscode_checksum=$(get_vscode_checksum "$version" "linux-deb-x64"); then
    show_progress warning "Could not fetch VS Code checksum (jq not available or API failed)"
    vscode_checksum=""
  fi

  # Check cache first if DEVBASE_DEB_CACHE is set
  local download_needed=true
  if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
    local cached_deb="${DEVBASE_DEB_CACHE}/vscode-${version}.deb"
    if [[ -f "$cached_deb" ]]; then
      show_progress info "Using cached VS Code package"
      cp "$cached_deb" "$vscode_deb"
      download_needed=false
    fi
  fi

  if [[ "$download_needed" == "true" ]]; then
    if retry_command download_file "$vscode_url" "$vscode_deb" "" "$vscode_checksum"; then
      # Save to cache if DEVBASE_DEB_CACHE is set
      if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
        mkdir -p "${DEVBASE_DEB_CACHE}"
        cp "$vscode_deb" "${DEVBASE_DEB_CACHE}/vscode-${version}.deb"
      fi
    else
      # Check if failure was due to checksum mismatch (security issue)
      if [[ -n "$vscode_checksum" ]] && [[ ! -f "$vscode_deb" ]]; then
        show_progress error "VS Code download/verification FAILED - SECURITY RISK"
        show_progress warning "Possible causes: MITM attack, corrupted mirror, or network issue"
        show_progress warning "Skipping VS Code installation for safety"
      else
        show_progress warning "VS Code download failed - skipping"
      fi
      return 1
    fi
  fi

  if [[ -f "$vscode_deb" ]]; then
    if sudo dpkg -i "$vscode_deb" 2>/dev/null; then
      show_progress success "VS Code installed ($version)"
    else
      show_progress warning "VS Code installation failed - trying to fix dependencies"
      sudo apt-get install -f -y -q &>/dev/null
      show_progress success "VS Code installed ($version, with dependency fixes)"
    fi
  else
    show_progress warning "VS Code download failed - skipping"
    return 1
  fi
}

# Brief: Install IntelliJ IDEA Ultimate with Wayland support
# Params: None
# Uses: _DEVBASE_TEMP, HOME, TOOL_VERSIONS, XDG_SESSION_TYPE, WAYLAND_DISPLAY, validate_var_set, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads and extracts IntelliJ, creates .desktop file, configures Wayland if applicable
install_intellij_idea() {
  validate_var_set "_DEVBASE_TEMP" || return 1
  validate_var_set "HOME" || return 1

  if [[ "${DEVBASE_INSTALL_INTELLIJ:-no}" != "yes" ]]; then
    show_progress info "IntelliJ IDEA installation skipped by user preference"
    return 0
  fi

  if [[ -d "$HOME/.local/share/JetBrains/IntelliJIdea" ]]; then
    show_progress info "IntelliJ IDEA already installed - skipping"
    return 0
  fi

  show_progress info "Installing IntelliJ IDEA..."
  local version="${TOOL_VERSIONS[intellij_idea]}"
  local idea_url="https://download.jetbrains.com/idea/ideaIU-${version}.tar.gz"
  local idea_checksum_url="${idea_url}.sha256"
  local idea_tar="${_DEVBASE_TEMP}/intellij-idea.tar.gz"
  local extract_dir="$HOME/.local/share/JetBrains"

  # Check cache first if DEVBASE_DEB_CACHE is set (reusing same cache dir for all binaries)
  local download_needed=true
  if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
    local cached_tar="${DEVBASE_DEB_CACHE}/intellij-${version}.tar.gz"
    if [[ -f "$cached_tar" ]]; then
      show_progress info "Using cached IntelliJ IDEA package"
      cp "$cached_tar" "$idea_tar"
      download_needed=false
    fi
  fi

  if [[ "$download_needed" == "true" ]]; then
    if retry_command download_file "$idea_url" "$idea_tar" "$idea_checksum_url"; then
      # Save to cache if DEVBASE_DEB_CACHE is set
      if [[ -n "${DEVBASE_DEB_CACHE:-}" ]]; then
        mkdir -p "${DEVBASE_DEB_CACHE}"
        cp "$idea_tar" "${DEVBASE_DEB_CACHE}/intellij-${version}.tar.gz"
      fi
    else
      show_progress warning "IntelliJ IDEA download failed - skipping"
      return 1
    fi
  fi

  if [[ -f "$idea_tar" ]]; then
    mkdir -p "$extract_dir"
    if tar -xzf "$idea_tar" -C "$extract_dir" 2>/dev/null; then
      local idea_dir
      idea_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "idea-IU-*" -o -name "ideaIU-*" | head -1)
      if [[ -n "$idea_dir" ]]; then
        mv "$idea_dir" "$extract_dir/IntelliJIdea"

        # Enable Wayland support if running on Wayland (JetBrains 2024.2+)
        if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
          show_progress info "Detected Wayland session - enabling Wayland support for IntelliJ"
          mkdir -p "$HOME/.config/JetBrains/IntelliJIdea2025.2"
          echo "-Dawt.toolkit.name=WLToolkit" >"$HOME/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
        fi

        mkdir -p "$HOME/.local/share/applications"
        cat >"$HOME/.local/share/applications/jetbrains-idea.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Ultimate
Icon=$extract_dir/IntelliJIdea/bin/idea.svg
Exec="$extract_dir/IntelliJIdea/bin/idea" %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
StartupNotify=true
EOF
        show_progress success "IntelliJ IDEA installed ($version)"
      else
        show_progress warning "IntelliJ IDEA directory not found in archive"
        return 1
      fi
    else
      show_progress warning "Failed to extract IntelliJ IDEA"
      return 1
    fi
  else
    show_progress warning "IntelliJ IDEA download failed - skipping"
    return 1
  fi
}
