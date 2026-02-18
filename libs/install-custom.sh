#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Global: Cached tool versions from packages.yaml (populated by _setup_custom_parser)
declare -gA TOOL_VERSIONS 2>/dev/null || true

# Global: Package format (deb or rpm) - set by _setup_custom_parser
_CUSTOM_PKG_FORMAT=""

# Brief: Get the package format for current distro (deb or rpm)
# Returns: deb or rpm
_get_custom_pkg_format() {
	if [[ -n "$_CUSTOM_PKG_FORMAT" ]]; then
		echo "$_CUSTOM_PKG_FORMAT"
		return
	fi

	# Try to use distro.sh if available
	if declare -f get_pkg_format &>/dev/null; then
		_CUSTOM_PKG_FORMAT=$(get_pkg_format)
	elif [[ -f "${DEVBASE_ROOT:-}/libs/distro.sh" ]]; then
		# shellcheck source=distro.sh
		source "${DEVBASE_ROOT}/libs/distro.sh"
		_CUSTOM_PKG_FORMAT=$(get_pkg_format)
	else
		# Fallback: detect by available command
		if command -v dpkg &>/dev/null; then
			_CUSTOM_PKG_FORMAT="deb"
		elif command -v rpm &>/dev/null; then
			_CUSTOM_PKG_FORMAT="rpm"
		else
			_CUSTOM_PKG_FORMAT="deb" # Default fallback
		fi
	fi

	echo "$_CUSTOM_PKG_FORMAT"
}

# Brief: Install a package based on format (deb or rpm)
# Params: $1 - package file path
# Returns: 0 on success, 1 on failure
_install_pkg_file() {
	local pkg_file="$1"
	local pkg_format
	pkg_format=$(_get_custom_pkg_format)

	if [[ ! -f "$pkg_file" ]]; then
		show_progress error "Package file not found: $pkg_file"
		return 1
	fi

	if [[ "$pkg_format" == "deb" ]]; then
		if sudo dpkg -i "$pkg_file"; then
			return 0
		else
			add_install_warning "Package installation failed - trying to fix dependencies"
			sudo apt-get install -f -y -q
			return 0
		fi
	else
		# RPM installation (try dnf, then rpm directly)
		if sudo dnf install -y "$pkg_file" 2>/dev/null ||
			sudo rpm -i "$pkg_file" 2>/dev/null; then
			return 0
		else
			add_install_warning "RPM installation failed"
			return 1
		fi
	fi
}

# Brief: Set up parser and load tool versions into TOOL_VERSIONS array
# Uses: DEVBASE_DOT, DEVBASE_LIBS, SELECTED_PACKS (globals)
# Returns: 0 on success
# Side-effects: Sources parse-packages.sh, populates TOOL_VERSIONS
_setup_custom_parser() {
	# Skip if already initialized (check array size safely with set -u)
	[[ -v TOOL_VERSIONS[@] ]] && [[ ${#TOOL_VERSIONS[@]} -gt 0 ]] && return 0

	require_env DEVBASE_DOT DEVBASE_LIBS || return 1

	# Set up package configuration
	export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
	export SELECTED_PACKS="${DEVBASE_SELECTED_PACKS:-$(get_default_packs)}"

	# Check for custom packages override
	if [[ -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]]; then
		require_env _DEVBASE_CUSTOM_PACKAGES || return 1
		if [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" ]]; then
			export PACKAGES_CUSTOM_YAML="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
		fi
	fi

	# Source parser if not already loaded
	if ! declare -f get_custom_packages &>/dev/null; then
		# shellcheck source=parse-packages.sh
		source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser"
	fi

	# Populate TOOL_VERSIONS array from packages.yaml
	# Format: "tool|version|installer|tags"
	while IFS='|' read -r tool version installer tags; do
		[[ -z "$tool" || -z "$version" ]] && continue
		TOOL_VERSIONS[$tool]="$version"
	done < <(get_custom_packages)

	return 0
}
_setup_custom_parser || true

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

	local sha_api="$DEVBASE_URL_VSCODE_SHA_API"
	local checksum
	checksum=$(retry_command curl -fsSL --connect-timeout 10 --max-time 30 "$sha_api" |
		jq -r --arg ver "$version" --arg plat "$platform" \
			'.products[] | select(.productVersion == $ver and .platform.os == $plat and .build == "stable") | .sha256hash')

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

	local checksum_url="${DEVBASE_URL_OCP_MIRROR}/${version}/sha256sum.txt"
	local checksum
	local filename="openshift-client-linux-${version}.tar.gz"

	if checksum=$(retry_command get_checksum_from_manifest "$checksum_url" "$filename" "30"); then
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


	if [[ "$DEVBASE_INSTALL_LAZYVIM" != "true" ]]; then
		show_progress info "LazyVim installation skipped by user preference"
		return 0
	fi

	show_progress info "Installing LazyVim..."

	local nvim_config="${XDG_CONFIG_HOME}/nvim"
	local backup_dir
	backup_dir="${XDG_CONFIG_HOME}/nvim.bak.$(date +%Y%m%d_%H%M%S)"
	local lazyvim_version="${TOOL_VERSIONS[lazyvim]:-main}"

	if [[ -d "$nvim_config" ]] && [[ ! -L "$nvim_config" ]]; then
		show_progress info "Backing up existing nvim config to $backup_dir"
		mv "$nvim_config" "$backup_dir"
	fi

	if ! command -v git &>/dev/null; then
		show_progress error "git not found, cannot install LazyVim"
		return 1
	fi

	show_progress info "Cloning LazyVim starter (version: $lazyvim_version)..."
	local git_output
	if git_output=$(git clone --quiet "$DEVBASE_URL_LAZYVIM_STARTER" "$nvim_config" 2>&1); then
		# Use subshell to avoid changing the caller's working directory
		(
			cd "$nvim_config" || exit 1

			# Checkout specific version (commit SHA or tag) if not main
			if [[ "$lazyvim_version" != "main" ]]; then
				git checkout --quiet "$lazyvim_version" 2>/dev/null || {
					add_install_warning "Failed to checkout $lazyvim_version, using main"
				}
			fi

			rm -rf .git
		)
		show_progress success "LazyVim starter installed ($lazyvim_version)"
	else
		show_progress error "Failed to clone LazyVim starter"
		if [[ -n "$git_output" ]]; then
			show_progress info "Error details: $git_output"
		fi
		return 1
	fi

	local theme_background="dark"
	if [[ "${DEVBASE_THEME}" == "everforest-light" ]]; then
		theme_background="light"
	fi

	local colorscheme_template="${DEVBASE_DOT}/.config/nvim/lua/plugins/colorscheme.lua.template"
	local colorscheme_target="$nvim_config/lua/plugins/colorscheme.lua"

	if [[ -f "$colorscheme_template" ]]; then
		mkdir -p "$(dirname "$colorscheme_target")"
		THEME_BACKGROUND="$theme_background" envsubst_preserve_undefined "$colorscheme_template" "$colorscheme_target"
		show_progress success "LazyVim colorscheme configured (${DEVBASE_THEME})"
	else
		add_install_warning "Colorscheme template not found"
	fi

	# Copy treesitter config to prevent compilation issues in VSCode
	local treesitter_source="${DEVBASE_DOT}/.config/nvim/lua/plugins/treesitter.lua"
	local treesitter_target="$nvim_config/lua/plugins/treesitter.lua"

	if [[ -f "$treesitter_source" ]]; then
		cp "$treesitter_source" "$treesitter_target"
		show_progress success "LazyVim treesitter configured (VSCode-compatible)"
	else
		add_install_warning "Treesitter config not found"
	fi

	return 0
}

# Brief: Install Oracle JDK Mission Control (JMC) for Java profiling
# Params: None
# Uses: _DEVBASE_TEMP, XDG_DATA_HOME, XDG_BIN_HOME, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file, backup_if_exists (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and extracts JMC, creates symlink in XDG_BIN_HOME
install_jmc() {
	validate_var_set "_DEVBASE_TEMP" || return 1
	validate_var_set "XDG_DATA_HOME" || return 1
	validate_var_set "XDG_BIN_HOME" || return 1


	if [[ -n "${TOOL_VERSIONS[jdk_mission_control]:-}" ]] && [[ "$DEVBASE_INSTALL_JMC" == "true" ]]; then
		if command_exists jmc; then
			show_progress success "JMC already installed"
			return 0
		else
			show_progress info "Installing JDK Mission Control..."
			local jmc_version="${TOOL_VERSIONS[jdk_mission_control]}"
			# JMC is available from Adoptium (Eclipse Temurin project)
			local jmc_url="${DEVBASE_URL_JMC_RELEASES}/${jmc_version}/org.openjdk.jmc-${jmc_version}-linux.gtk.x86_64.tar.gz"
			local jmc_tar="${_DEVBASE_TEMP}/jmc.tar.gz"

			if ! download_with_cache "$jmc_url" "$jmc_tar" "jmc-${jmc_version}.tar.gz" "JMC package"; then
				add_install_warning "JMC download failed - skipping"
				return 0
			fi

			if [[ -f "$jmc_tar" ]]; then
				tui_run_cmd "Extracting JMC" tar -C "${_DEVBASE_TEMP}" -xzf "$jmc_tar"
				backup_if_exists "${XDG_DATA_HOME}/JDK Mission Control" "jmc-old"

				# Adoptium archive extracts directly to "JDK Mission Control" directory
				local extracted_dir="${_DEVBASE_TEMP}/JDK Mission Control"
				if [[ -d "$extracted_dir" ]]; then
					mv -f "$extracted_dir" "${XDG_DATA_HOME}/"
				else
					add_install_warning "Unexpected JMC archive structure - skipping"
					return 0
				fi
				ln -sf "${XDG_DATA_HOME}/JDK Mission Control/jmc" "${XDG_BIN_HOME}/jmc"

				# Create desktop file for application menu
				local jmc_install_dir="${XDG_DATA_HOME}/JDK Mission Control"
				local jmc_icon="${jmc_install_dir}/icon.xpm"

				# Fallback to generic Java icon if JMC icon not found
				if [[ ! -f "$jmc_icon" ]]; then
					jmc_icon="java"
				fi

				mkdir -p "$HOME/.local/share/applications"
				cat >"$HOME/.local/share/applications/jmc.desktop" <<DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JDK Mission Control
GenericName=Java Profiler
Comment=Advanced Java profiling and diagnostics tool
Exec="${jmc_install_dir}/jmc"
Icon=${jmc_icon}
Categories=Development;Java;Profiler;Debugger;
Terminal=false
StartupNotify=true
StartupWMClass=jmc
DESKTOP_EOF

				show_progress success "JDK Mission Control installed"
			else
				add_install_warning "JMC download failed - skipping"
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
	local oc_url="${DEVBASE_URL_OCP_MIRROR}/${oc_version}/openshift-client-linux.tar.gz"
	local oc_tar="${_DEVBASE_TEMP}/openshift-client.tar.gz"

	# Get expected checksum using helper function
	local expected_checksum=""
	if ! expected_checksum=$(get_oc_checksum "$oc_version"); then
		add_install_warning "Could not fetch OpenShift CLI checksum"
		expected_checksum=""
	fi

	# OpenShift mirror can be slow, use 60s timeout (default is 30s)
	if download_file "$oc_url" "$oc_tar" "" "$expected_checksum" "" "60"; then
		tui_run_cmd "Extracting OpenShift CLI" tar -C "${_DEVBASE_TEMP}" -xzf "$oc_tar"

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
			add_install_warning "Possible causes: MITM attack, corrupted mirror, or network issue"
			add_install_warning "Skipping OpenShift CLI installation for safety"
		else
			add_install_warning "OpenShift CLI download failed - skipping"
		fi
	fi
}

# Brief: Install DBeaver Community Edition database tool
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and installs DBeaver package (deb or rpm based on distro)
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
	local pkg_format
	pkg_format=$(_get_custom_pkg_format)

	local dbeaver_url dbeaver_pkg cache_name
	if [[ "$pkg_format" == "deb" ]]; then
		dbeaver_url="${DEVBASE_URL_DBEAVER_RELEASES}/${dbeaver_version}/dbeaver-ce_${dbeaver_version}_amd64.deb"
		cache_name="dbeaver-${dbeaver_version}.deb"
	else
		dbeaver_url="${DEVBASE_URL_DBEAVER_RELEASES}/${dbeaver_version}/dbeaver-ce-${dbeaver_version}-stable.x86_64.rpm"
		cache_name="dbeaver-${dbeaver_version}.rpm"
	fi
	dbeaver_pkg="${_DEVBASE_TEMP}/${cache_name}"

	if ! download_with_cache "$dbeaver_url" "$dbeaver_pkg" "$cache_name" "DBeaver package"; then
		add_install_warning "DBeaver download failed - skipping"
		return 0
	fi

	if _install_pkg_file "$dbeaver_pkg"; then
		show_progress success "DBeaver installed"
	else
		add_install_warning "DBeaver installation failed"
	fi
}

# Brief: Install KeyStore Explorer for Java keystore management
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 always (prints warnings on failure)
# Side-effects: Downloads and installs KeyStore Explorer package (deb or rpm)
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
	local pkg_format
	pkg_format=$(_get_custom_pkg_format)

	# KeyStore Explorer only provides deb, but it's architecture-independent Java
	# For RPM systems, we can use alien or download the tarball instead
	local kse_url kse_pkg cache_name
	if [[ "$pkg_format" == "deb" ]]; then
		kse_url="${DEVBASE_URL_KSE_RELEASES}/${kse_version}/kse_${kse_version#v}_all.deb"
		cache_name="kse-${kse_version}.deb"
		kse_pkg="${_DEVBASE_TEMP}/${cache_name}"

		if ! download_with_cache "$kse_url" "$kse_pkg" "$cache_name" "KeyStore Explorer package"; then
			add_install_warning "KeyStore Explorer download failed - skipping"
			return 0
		fi

		if _install_pkg_file "$kse_pkg"; then
			show_progress success "KeyStore Explorer installed"
		else
			add_install_warning "KeyStore Explorer installation failed"
		fi
	else
		# For RPM systems, download the zip/tarball and install manually
		kse_url="${DEVBASE_URL_KSE_RELEASES}/${kse_version}/kse-${kse_version#v}.zip"
		cache_name="kse-${kse_version}.zip"
		kse_pkg="${_DEVBASE_TEMP}/${cache_name}"

		if ! download_with_cache "$kse_url" "$kse_pkg" "$cache_name" "KeyStore Explorer package"; then
			add_install_warning "KeyStore Explorer download failed - skipping"
			return 0
		fi

		if [[ -f "$kse_pkg" ]]; then
			local kse_dir="${XDG_DATA_HOME:-$HOME/.local/share}/keystore-explorer"
			mkdir -p "$kse_dir"
			unzip -q -o "$kse_pkg" -d "$kse_dir"
			ln -sf "$kse_dir/kse-${kse_version#v}/kse.sh" "${XDG_BIN_HOME:-$HOME/.local/bin}/kse"
			chmod +x "${XDG_BIN_HOME:-$HOME/.local/bin}/kse"
			show_progress success "KeyStore Explorer installed"
		else
			add_install_warning "KeyStore Explorer installation failed"
		fi
	fi
}

# Brief: Install k3s lightweight Kubernetes distribution
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads and runs k3s installer script
install_k3s() {
	validate_var_set "_DEVBASE_TEMP" || return 1


	if [[ -z "${TOOL_VERSIONS[k3s]:-}" ]]; then
		show_progress info "k3s not configured - skipping"
		return 0
	fi

	if command -v k3s &>/dev/null; then
		show_progress info "k3s already installed - skipping"
		return 0
	fi

	show_progress info "Installing k3s..."
	local k3s_version="${TOOL_VERSIONS[k3s]}"
	local install_url="${DEVBASE_URL_K3S_RAW}/${k3s_version}/install.sh"
	local install_script="${_DEVBASE_TEMP}/k3s-install.sh"
	local expected_checksum="${DEVBASE_K3S_INSTALL_SHA256:-}"

	if ! require_remote_script_checksum "$install_url" "$expected_checksum" "k3s installer"; then
		return 1
	fi

	show_progress info "Verifying k3s installer checksum"

	if download_file "$install_url" "$install_script" "" "$expected_checksum"; then
		chmod +x "$install_script"
		if tui_run_cmd "Installing k3s" env INSTALL_K3S_VERSION="$k3s_version" sh "$install_script"; then
			show_progress success "k3s installed and started ($k3s_version)"
		else
			add_install_warning "k3s installation failed - skipping"
			return 1
		fi
	else
		add_install_warning "k3s installer download failed - skipping"
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


	if [[ -z "${TOOL_VERSIONS[fisher]:-}" ]]; then
		show_progress info "Fisher not configured - skipping"
		return 0
	fi

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

	local git_output
	if git_output=$(git clone --quiet --depth 1 --branch "${fisher_version}" "$DEVBASE_URL_FISHER_REPO" "$fisher_dir" 2>&1); then
		if fish -c "source $fisher_dir/functions/fisher.fish && fisher install jorgebucaran/fisher" >/dev/null 2>&1; then
			show_progress success "Fisher installed ($fisher_version)"

			# Install fzf.fish plugin
			show_progress info "Installing fzf.fish plugin..."
			if fish -c "fisher install PatrickF1/fzf.fish" >/dev/null 2>&1; then
				show_progress success "fzf.fish plugin installed (Ctrl+R for history, Ctrl+Alt+F for files)"
			else
				add_install_warning "fzf.fish plugin installation failed"
				return 1
			fi
		else
			show_progress error "Fisher installation failed"
			return 1
		fi
	else
		show_progress error "Failed to clone Fisher repository"
		if [[ -n "$git_output" ]]; then
			show_progress info "Error details: $git_output"
		fi
		return 1
	fi

	return 0
}

# Note: install_reuse() function removed - reuse is now managed by mise
# See .mise.toml: "pipx:reuse" = "6.2.0"

# Brief: Determine font details (name, zip, directory, display name, timeout) from font choice
# Params: $1 - font choice name
# Returns: Echoes "font_name font_zip_name font_dir_name font_display_name timeout" to stdout
_determine_font_details() {
	local font_choice="$1"
	local font_name=""
	local font_zip_name=""
	local font_dir_name=""
	local font_display_name=""
	local timeout="300"

	case "$font_choice" in
	jetbrains-mono)
		font_name="JetBrainsMono"
		font_zip_name="JetBrainsMono.zip"
		font_dir_name="JetBrainsMonoNerdFont"
		font_display_name="JetBrains Mono Nerd Font"
		;;
	firacode)
		font_name="FiraCode"
		font_zip_name="FiraCode.zip"
		font_dir_name="FiraCodeNerdFont"
		font_display_name="Fira Code Nerd Font"
		timeout="180"
		;;
	cascadia-code)
		font_name="CascadiaCode"
		font_zip_name="CascadiaCode.zip"
		font_dir_name="CascadiaCodeNerdFont"
		font_display_name="Cascadia Code Nerd Font"
		;;
	monaspace)
		font_name="Monaspace"
		font_zip_name="Monaspace.zip"
		font_dir_name="MonaspaceNerdFont"
		font_display_name="Monaspace Nerd Font"
		;;
	*)
		add_install_warning "Unknown font choice: $font_choice, defaulting to JetBrains Mono"
		font_name="JetBrainsMono"
		font_zip_name="JetBrainsMono.zip"
		font_dir_name="JetBrainsMonoNerdFont"
		font_display_name="JetBrains Mono Nerd Font"
		;;
	esac

	echo "$font_name|$font_zip_name|$font_dir_name|$font_display_name|$timeout"
}

# Brief: Check if font is already installed
# Params: $1 - font directory path
# Returns: 0 if installed, 1 otherwise
_check_font_installed() {
	local font_dir="$1"

	if [[ -d "$font_dir" ]] && [[ $(find "$font_dir" \( -name "*.ttf" -o -name "*.otf" \) | wc -l) -gt 0 ]]; then
		return 0
	fi
	return 1
}

# Brief: Fetch Nerd Font checksum from release manifest
# Params: $1 - nf_version, $2 - font_zip_name
# Returns: 0 with checksum on stdout, 1 on failure
get_nerd_font_checksum() {
	local nf_version="$1"
	local font_zip_name="$2"

	validate_not_empty "$nf_version" "Nerd Fonts version" || return 1
	validate_not_empty "$font_zip_name" "Nerd Fonts package" || return 1

	local checksum_url="${DEVBASE_URL_NERD_FONTS_RELEASES}/${nf_version}/SHA256SUMS"
	local checksum

	if checksum=$(get_checksum_from_manifest "$checksum_url" "$font_zip_name" "60"); then
		if [[ -n "$checksum" ]]; then
			echo "$checksum"
			return 0
		fi
	fi

	return 1
}

# Brief: Download Nerd Font to cache with version tracking
# Params: $1 - font_zip_name, $2 - cache_dir, $3 - nf_version, $4 - timeout
# Returns: 0 on success (downloaded or cached), 1 on failure
_download_font_to_cache() {
	local font_zip_name="$1"
	local cache_dir="$2"
	local nf_version="$3"
	local timeout="$4"

	local font_url="${DEVBASE_URL_NERD_FONTS_RELEASES}/${nf_version}/${font_zip_name}"
	local versioned_cache_dir="${cache_dir}/${nf_version}"
	local font_zip="${versioned_cache_dir}/${font_zip_name}"
	local version_file="${versioned_cache_dir}/.version"

	# Check if already cached with correct version
	if [[ -f "$font_zip" ]] && [[ -f "$version_file" ]]; then
		local cached_version
		cached_version=$(cat "$version_file" 2>/dev/null || echo "")
		if [[ "$cached_version" == "$nf_version" ]]; then
			return 0
		fi
	fi

	# Download new version
	mkdir -p "$versioned_cache_dir"
	local expected_checksum=""

	if expected_checksum=$(get_nerd_font_checksum "$nf_version" "$font_zip_name"); then
		if download_file "$font_url" "$font_zip" "" "$expected_checksum" "" "$timeout"; then
			echo "$nf_version" >"$version_file"
			return 0
		fi
	else
		add_install_warning "No checksum found for ${font_zip_name} - continuing without verification"
		if download_file "$font_url" "$font_zip" "" "" "" "$timeout"; then
			echo "$nf_version" >"$version_file"
			return 0
		fi
	fi

	return 1
}

# Brief: Extract font from cache to installation directory
# Params: $1 - font_zip_path, $2 - font_dir
# Returns: 0 on success, 1 on failure
_extract_font_from_cache() {
	local font_zip="$1"
	local font_dir="$2"

	if [[ ! -f "$font_zip" ]]; then
		return 1
	fi

	mkdir -p "$font_dir"
	unzip -q -o "$font_zip" "*.ttf" "*.otf" -d "$font_dir" 2>/dev/null || true

	_check_font_installed "$font_dir"
}

# Brief: Download all Nerd Fonts to cache for offline use
# Params: $1 - cache_dir, $2 - nf_version
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads all 4 supported Nerd Fonts to versioned cache directory
_download_all_fonts_to_cache() {
	local cache_dir="$1"
	local nf_version="$2"
	local all_fonts="jetbrains-mono firacode cascadia-code monaspace"
	local failed_count=0

	show_progress info "Downloading all Nerd Fonts ($nf_version) to cache..."

	for font in $all_fonts; do
		local font_details
		font_details=$(_determine_font_details "$font")
		local font_name font_zip_name font_dir_name font_display_name timeout
		IFS='|' read -r font_name font_zip_name font_dir_name font_display_name timeout <<<"$font_details"

		if _download_font_to_cache "$font_zip_name" "$cache_dir" "$nf_version" "$timeout"; then
			show_progress success "$font_display_name cached"
		else
			add_install_warning "Failed to cache $font_display_name"
			((failed_count++))
		fi
	done

	if [[ $failed_count -gt 0 ]]; then
		add_install_warning "$failed_count font(s) failed to download"
	fi

	return 0
}

# Brief: Install selected Nerd Font for terminal use (native Ubuntu only, skips WSL)
# Params: None
# Uses: _DEVBASE_TEMP, HOME, DEVBASE_FONT, DEVBASE_CACHE_DIR, TOOL_VERSIONS, validate_var_set, is_wsl, show_progress (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads all fonts to versioned cache, installs selected font to ~/.local/share/fonts, updates font cache
install_nerd_fonts() {
	validate_var_set "_DEVBASE_TEMP" || return 1
	validate_var_set "HOME" || return 1
	validate_var_set "DEVBASE_CACHE_DIR" || return 1


	if is_wsl; then
		show_progress info "Skipping Nerd Font installation on WSL (manage fonts on Windows)"
		return 0
	fi

	# Get version from config
	local nf_version="${TOOL_VERSIONS[nerd_fonts]:-v3.4.0}"
	local font_cache_dir="${DEVBASE_CACHE_DIR}/fonts"

	# Try to download all fonts to cache (best effort)
	_download_all_fonts_to_cache "$font_cache_dir" "$nf_version"

	# Install selected font
	local font_choice="${DEVBASE_FONT:-$(get_default_font)}"
	local font_details
	font_details=$(_determine_font_details "$font_choice")

	local font_name font_zip_name font_dir_name font_display_name timeout
	IFS='|' read -r font_name font_zip_name font_dir_name font_display_name timeout <<<"$font_details"

	show_progress info "Installing $font_display_name..."

	local fonts_dir="${HOME}/.local/share/fonts"
	local font_dir="${fonts_dir}/${font_dir_name}"

	# Check if already installed
	if _check_font_installed "$font_dir"; then
		show_progress success "$font_display_name already installed"
		export DEVBASE_FONTS_INSTALLED="true"
		return 0
	fi

	# Check if font is in cache
	local font_zip="${font_cache_dir}/${nf_version}/${font_zip_name}"
	if [[ ! -f "$font_zip" ]]; then
		show_progress error "Font not in cache: $font_zip"
		show_progress error "Failed to download $font_display_name"
		return 1
	fi

	# Extract and install from cache
	if _extract_font_from_cache "$font_zip" "$font_dir"; then
		if command -v fc-cache &>/dev/null; then
			fc-cache -f "$fonts_dir"
		fi

		show_progress success "$font_display_name installed ($nf_version)"
		export DEVBASE_FONTS_INSTALLED="true"
		return 0
	else
		show_progress error "Failed to extract $font_display_name from cache"
		return 1
	fi
}

# Brief: Apply GNOME Terminal theme colors
# Params: $1 - theme name, $2 - profile ID
# Returns: 0 on success, 1 on failure
# Side-effects: Updates GNOME Terminal color scheme via gsettings
apply_gnome_terminal_theme() {
	local theme_name="$1"
	local profile_id="$2"

	if [[ -z "$profile_id" ]]; then
		return 1
	fi

	local profile_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/"

	# Color variables
	local bg fg cursor
	local -a palette

	case "$theme_name" in
	everforest-dark)
		bg='#272E33'
		fg='#D3C6AA'
		cursor='#D3C6AA'
		palette=('#2E383C' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA' '#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8')
		;;
	everforest-light)
		bg='#FDF6E3'
		fg='#5C6A72'
		cursor='#5C6A72'
		palette=('#5C6A72' '#F85552' '#8DA101' '#DFA000' '#3A94C5' '#DF69BA' '#35A77C' '#DFDDC8' '#343F44' '#E67E80' '#A7C080' '#DBBC7F' '#7FBBB3' '#D699B6' '#83C092' '#D3C6AA')
		;;
	catppuccin-mocha)
		bg='#1E1E2E'
		fg='#CDD6F4'
		cursor='#CDD6F4'
		palette=('#45475A' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#BAC2DE' '#585B70' '#F38BA8' '#A6E3A1' '#F9E2AF' '#89B4FA' '#F5C2E7' '#94E2D5' '#A6ADC8')
		;;
	catppuccin-latte)
		bg='#EFF1F5'
		fg='#4C4F69'
		cursor='#4C4F69'
		palette=('#5C5F77' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#ACB0BE' '#6C6F85' '#D20F39' '#40A02B' '#DF8E1D' '#1E66F5' '#EA76CB' '#179299' '#BCC0CC')
		;;
	tokyonight-night)
		bg='#1A1B26'
		fg='#C0CAF5'
		cursor='#C0CAF5'
		palette=('#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#A9B1D6' '#414868' '#F7768E' '#9ECE6A' '#E0AF68' '#7AA2F7' '#BB9AF7' '#7DCFFF' '#C0CAF5')
		;;
	tokyonight-day)
		bg='#D5D6DB'
		fg='#565A6E'
		cursor='#565A6E'
		palette=('#0F0F14' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58' '#9699A3' '#8C4351' '#485E30' '#8F5E15' '#34548A' '#5A4A78' '#0F4B6E' '#343B58')
		;;
	gruvbox-dark)
		bg='#282828'
		fg='#EBDBB2'
		cursor='#EBDBB2'
		palette=('#282828' '#CC241D' '#98971A' '#D79921' '#458588' '#B16286' '#689D6A' '#A89984' '#928374' '#FB4934' '#B8BB26' '#FABD2F' '#83A598' '#D3869B' '#8EC07C' '#EBDBB2')
		;;
	gruvbox-light)
		bg='#FBF1C7'
		fg='#654735'
		cursor='#654735'
		palette=('#FBF1C7' '#CC241D' '#98971A' '#D79921' '#458588' '#B16286' '#689D6A' '#7C6F64' '#928374' '#9D0006' '#79740E' '#B57614' '#076678' '#8F3F71' '#427B58' '#3C3836')
		;;
	nord)
		bg='#2E3440'
		fg='#D8DEE9'
		cursor='#D8DEE9'
		palette=('#3B4252' '#BF616A' '#A3BE8C' '#EBCB8B' '#81A1C1' '#B48EAD' '#88C0D0' '#E5E9F0' '#4C566A' '#BF616A' '#A3BE8C' '#EBCB8B' '#81A1C1' '#B48EAD' '#8FBCBB' '#ECEFF4')
		;;
	dracula)
		bg='#282A36'
		fg='#F8F8F2'
		cursor='#F8F8F2'
		palette=('#21222C' '#FF5555' '#50FA7B' '#F1FA8C' '#BD93F9' '#FF79C6' '#8BE9FD' '#F8F8F2' '#6272A4' '#FF6E6E' '#69FF94' '#FFFFA5' '#D6ACFF' '#FF92DF' '#A4FFFF' '#FFFFFF')
		;;
	solarized-dark)
		bg='#002B36'
		fg='#839496'
		cursor='#839496'
		palette=('#073642' '#DC322F' '#859900' '#B58900' '#268BD2' '#D33682' '#2AA198' '#EEE8D5' '#002B36' '#CB4B16' '#586E75' '#657B83' '#839496' '#6C71C4' '#93A1A1' '#FDF6E3')
		;;
	solarized-light)
		bg='#FDF6E3'
		fg='#657B83'
		cursor='#657B83'
		palette=('#073642' '#DC322F' '#859900' '#B58900' '#268BD2' '#D33682' '#2AA198' '#EEE8D5' '#002B36' '#CB4B16' '#586E75' '#657B83' '#839496' '#6C71C4' '#93A1A1' '#FDF6E3')
		;;
	*)
		return 0 # Unknown theme, skip
		;;
	esac

	# Build palette string
	local palette_str="["
	for i in "${!palette[@]}"; do
		palette_str+="'${palette[$i]}'"
		if [[ $i -lt $((${#palette[@]} - 1)) ]]; then
			palette_str+=", "
		fi
	done
	palette_str+="]"

	# Apply settings
	gsettings set "$profile_path" use-theme-colors false 2>/dev/null || true
	gsettings set "$profile_path" background-color "$bg" 2>/dev/null || true
	gsettings set "$profile_path" foreground-color "$fg" 2>/dev/null || true
	gsettings set "$profile_path" cursor-background-color "$cursor" 2>/dev/null || true
	gsettings set "$profile_path" cursor-foreground-color "$bg" 2>/dev/null || true
	gsettings set "$profile_path" palette "$palette_str" 2>/dev/null || true
	gsettings set "$profile_path" bold-color-same-as-fg true 2>/dev/null || true

	return 0
}

# Brief: Configure terminal fonts to use selected Nerd Font (GNOME Terminal and Ghostty)
# Params: None
# Uses: HOME, DEVBASE_FONT, command_exists, show_progress (globals/functions)
# Returns: 0 on success, 1 if fonts not installed
# Side-effects: Updates GNOME Terminal gsettings and Ghostty config file to use selected font
configure_terminal_fonts() {
	validate_var_set "HOME" || return 1

	# Reuse _determine_font_details for shared fields (font_dir_name, font_display_name)
	local font_choice="${DEVBASE_FONT:-$(get_default_font)}"
	local font_details
	font_details=$(_determine_font_details "$font_choice")
	local font_dir_name font_display_name
	IFS='|' read -r _ _ font_dir_name font_display_name _ <<<"$font_details"

	# font_family_name is only needed here (terminal monospace family name)
	local font_family_name=""
	case "$font_choice" in
	jetbrains-mono) font_family_name="JetBrainsMono Nerd Font Mono" ;;
	firacode) font_family_name="FiraCode Nerd Font Mono" ;;
	cascadia-code) font_family_name="CaskaydiaCove Nerd Font Mono" ;;
	monaspace) font_family_name="MonaspiceNe Nerd Font Mono" ;;
	*) font_family_name="JetBrainsMono Nerd Font Mono" ;;
	esac

	# Check if fonts are installed
	local fonts_dir="${HOME}/.local/share/fonts"
	local font_dir="${fonts_dir}/${font_dir_name}"

	if ! _check_font_installed "$font_dir"; then
		add_install_warning "$font_display_name not installed - skipping terminal configuration"
		return 1
	fi

	local configured=false

	# Configure GNOME Terminal to use selected font (if installed)
	if command -v gsettings &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
		local profile_id
		profile_id=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
		if [[ -n "$profile_id" ]]; then
			gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/" font "${font_family_name} 11" 2>/dev/null || true
			gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/" use-system-font false 2>/dev/null || true
			show_progress success "GNOME Terminal: Font configured ($font_display_name)"
			configured=true

			# Note: Theme colors are applied separately in configure_fonts_post_install()
			# before this function is called, so we don't apply them here
		fi
	fi

	# Configure Ghostty (if config exists)
	local ghostty_config="${HOME}/.config/ghostty/config"
	if [[ -f "$ghostty_config" ]]; then
		# Check if font-family is already set
		if ! grep -q "^font-family" "$ghostty_config"; then
			echo "" >>"$ghostty_config"
			echo "# Nerd Font for icons and symbols" >>"$ghostty_config"
			echo "font-family = \"${font_family_name}\"" >>"$ghostty_config"
			show_progress success "Ghostty: Font configured ($font_display_name)"
			configured=true
		else
			show_progress info "Ghostty font already configured - skipping"
		fi
	fi

	if [[ "$configured" == "false" ]]; then
		show_progress info "No compatible terminals found (GNOME Terminal or Ghostty)"
	fi

	return 0
}

# Brief: Install Visual Studio Code (native Linux only, skips WSL)
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, is_wsl, command_exists, show_progress, get_vscode_checksum, retry_command, download_file (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads and installs VS Code package (deb or rpm) with checksum verification
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
	local pkg_format
	pkg_format=$(_get_custom_pkg_format)

	local vscode_url vscode_pkg cache_name platform_name
	if [[ "$pkg_format" == "deb" ]]; then
		platform_name="linux-deb-x64"
		cache_name="vscode-${version}.deb"
	else
		platform_name="linux-rpm-x64"
		cache_name="vscode-${version}.rpm"
	fi
	vscode_url="${DEVBASE_URL_VSCODE_DOWNLOAD}/${version}/${platform_name}/stable"
	vscode_pkg="${_DEVBASE_TEMP}/${cache_name}"

	local vscode_checksum
	if ! vscode_checksum=$(get_vscode_checksum "$version" "$platform_name"); then
		add_install_warning "Could not fetch VS Code checksum (jq not available or API failed)"
		vscode_checksum=""
	fi

	if ! download_with_cache "$vscode_url" "$vscode_pkg" "$cache_name" "VS Code" "" "$vscode_checksum"; then
		add_install_warning "VS Code download failed - skipping"
		return 1
	fi

	if _install_pkg_file "$vscode_pkg"; then
		show_progress success "VS Code installed ($version)"
	else
		add_install_warning "VS Code installation failed"
		return 1
	fi
}

# Brief: Download IntelliJ IDEA archive with cache support
# Params: $1 - version, $2 - temp dir
# Returns: 0 on success, 1 on failure; echoes tar path to stdout
_download_intellij_archive() {
	local version="$1"
	local temp_dir="$2"
	local idea_url="${DEVBASE_URL_JETBRAINS_DOWNLOAD}/ideaIU-${version}.tar.gz"
	local idea_checksum_url="${idea_url}.sha256"
	local idea_tar="${temp_dir}/intellij-idea.tar.gz"

	show_progress info "Downloading IntelliJ IDEA ${version} (~900MB, this may take a few minutes)..."
	# Use 600 second (10 minute) timeout for large file download
	if ! download_with_cache "$idea_url" "$idea_tar" "intellij-${version}.tar.gz" "IntelliJ IDEA" \
		"$idea_checksum_url" "" 600; then
		add_install_warning "IntelliJ IDEA download failed - skipping"
		return 1
	fi

	echo "$idea_tar"
	return 0
}

# Brief: Extract and move IntelliJ IDEA to installation directory
# Params: $1 - tar file path, $2 - extract directory
# Returns: 0 on success and echoes install path, 1 on failure
_extract_and_install_intellij() {
	local idea_tar="$1"
	local extract_dir="$2"

	mkdir -p "$extract_dir"
	show_progress info "Extracting IntelliJ IDEA (this may take a few minutes)..." >&2

	if ! tar -xzf "$idea_tar" -C "$extract_dir"; then
		add_install_warning "Failed to extract IntelliJ IDEA"
		return 1
	fi

	local idea_dir
	idea_dir=$(find "$extract_dir" -maxdepth 1 -type d \( -name "idea-IU-*" -o -name "ideaIU-*" \) | head -1)

	if [[ -z "$idea_dir" ]]; then
		add_install_warning "IntelliJ IDEA directory not found in archive"
		return 1
	fi

	mv "$idea_dir" "$extract_dir/IntelliJIdea"
	echo "$extract_dir/IntelliJIdea"
	return 0
}

# Brief: Read installed IntelliJ IDEA version
# Params: $1 - install directory
# Returns: 0 with version on stdout, 1 if unavailable
_get_intellij_installed_version() {
	local install_dir="$1"
	local product_info="${install_dir}/product-info.json"

	if [[ ! -f "$product_info" ]]; then
		return 1
	fi

	local version
	version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$product_info" | head -1 | cut -d'"' -f4)

	if [[ -n "$version" ]]; then
		echo "$version"
		return 0
	fi

	return 1
}

# Brief: Check if running on Wayland session
# Returns: 0 if Wayland, 1 otherwise
_is_wayland_session() {
	[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]
}

# Brief: Configure IntelliJ VM options from template
# Params: $1 - version, $2 - vmoptions template path
# Returns: 0 always
_configure_intellij_vmoptions() {
	local version="$1"
	local vmoptions_template="$2"

	local idea_version_short
	idea_version_short=$(echo "$version" | grep -oP '^\d+\.\d+')
	local idea_config_dir="$HOME/.config/JetBrains/IntelliJIdea${idea_version_short}"
	local vmoptions_file="${idea_config_dir}/idea64.vmoptions"

	mkdir -p "$idea_config_dir"

	if [[ -f "$vmoptions_template" ]]; then
		show_progress info "Configuring IntelliJ VM options for optimal performance..."

		if _is_wayland_session; then
			sed 's|# WAYLAND_PLACEHOLDER|-Dawt.toolkit.name=WLToolkit|' "$vmoptions_template" >"$vmoptions_file"
			# Disable Wayland shadow rendering to avoid shadow artifacts (IJPL-203429)
			echo "-Dsun.awt.wl.Shadow=false" >>"$vmoptions_file"
			show_progress info "Wayland support enabled"
		else
			sed '/# WAYLAND_PLACEHOLDER/d' "$vmoptions_template" >"$vmoptions_file"
		fi

		show_progress success "IntelliJ VM options configured (Xmx=4GB, optimized for medium projects)"
	else
		if _is_wayland_session; then
			show_progress info "Detected Wayland session - enabling Wayland support for IntelliJ"
			printf '%s\n' "-Dawt.toolkit.name=WLToolkit" "-Dsun.awt.wl.Shadow=false" >"$vmoptions_file"
		fi
	fi

	return 0
}

# Brief: Create IntelliJ IDEA desktop file
# Params: $1 - install directory path
# Returns: 0 always
_create_intellij_desktop_file() {
	local install_dir="$1"

	mkdir -p "$HOME/.local/share/applications"
	cat >"$HOME/.local/share/applications/jetbrains-idea.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Ultimate
Icon=$install_dir/bin/idea.svg
Exec="$install_dir/bin/idea" %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
StartupNotify=true
EOF
	return 0
}

# Brief: Install IntelliJ IDEA Ultimate with Wayland support
# Params: None
# Uses: _DEVBASE_TEMP, HOME, TOOL_VERSIONS, XDG_SESSION_TYPE, WAYLAND_DISPLAY, validate_var_set, show_progress, retry_command, download_file (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads and extracts IntelliJ, creates .desktop file, configures Wayland if applicable
install_intellij_idea() {
	validate_var_set "_DEVBASE_TEMP" || return 1
	validate_var_set "HOME" || return 1


	if [[ "$DEVBASE_INSTALL_INTELLIJ" != "true" ]]; then
		show_progress info "IntelliJ IDEA installation skipped by user preference"
		return 0
	fi

	if [[ -z "${TOOL_VERSIONS[intellij_idea]:-}" ]]; then
		show_progress info "IntelliJ IDEA not configured - skipping"
		return 0
	fi

	local version="${TOOL_VERSIONS[intellij_idea]}"
	local extract_dir="$HOME/.local/share/JetBrains"
	local install_root="$extract_dir/IntelliJIdea"

	if [[ -d "$install_root" ]]; then
		local installed_version
		installed_version=$(_get_intellij_installed_version "$install_root" || true)

		if [[ -n "$installed_version" ]]; then
			if [[ "$installed_version" == "$version" ]]; then
				show_progress success "IntelliJ IDEA already installed ($installed_version)"
				_create_intellij_desktop_file "$install_root"
				return 0
			fi

			local newest
			newest=$(printf '%s\n%s\n' "$installed_version" "$version" | sort -V | tail -1)
			if [[ "$newest" == "$installed_version" ]]; then
				add_install_warning "Installed IntelliJ IDEA ($installed_version) is newer than pinned ($version) - skipping downgrade"
				_create_intellij_desktop_file "$install_root"
				return 0
			fi

			show_progress info "Updating IntelliJ IDEA from $installed_version to $version..."
		else
			show_progress info "Existing IntelliJ IDEA detected - reinstalling to $version..."
		fi

		backup_if_exists "$install_root" "old"
	fi

	show_progress info "Installing IntelliJ IDEA..."

	local idea_tar
	if ! idea_tar=$(_download_intellij_archive "$version" "$_DEVBASE_TEMP"); then
		return 1
	fi

	local install_dir
	if ! install_dir=$(_extract_and_install_intellij "$idea_tar" "$extract_dir"); then
		return 1
	fi

	local vmoptions_template="${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"
	_configure_intellij_vmoptions "$version" "$vmoptions_template"

	_create_intellij_desktop_file "$install_dir"

	show_progress success "IntelliJ IDEA installed ($version)"
	return 0
}

# Brief: Get SHA256 checksum for gum package from checksums.txt
# Params: $1 - version (e.g. "0.17.0"), $2 - package name (e.g. "gum_0.17.0_amd64.deb")
# Returns: 0 with checksum on stdout if found, 1 if not found
# Side-effects: Makes curl request to GitHub releases
get_gum_checksum() {
	local version="$1"
	local package_name="$2"

	validate_not_empty "$version" "gum version" || return 1
	validate_not_empty "$package_name" "package name" || return 1

	local checksums_url="${DEVBASE_URL_GUM_RELEASES}/v${version}/checksums.txt"
	local checksum

	if checksum=$(retry_command get_checksum_from_manifest "$checksums_url" "$package_name" "30"); then
		if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
			echo "$checksum"
			return 0
		fi
	fi

	return 1
}

# Brief: Install gum TUI tool from Charm
# Params: None
# Uses: _DEVBASE_TEMP, TOOL_VERSIONS, validate_var_set, command_exists, show_progress, get_gum_checksum, download_file (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Downloads and installs gum package (deb or rpm) with checksum verification
install_gum() {
	validate_var_set "_DEVBASE_TEMP" || return 1


	if command_exists gum; then
		local current_version
		current_version=$(gum --version 2>/dev/null | head -1 | awk '{print $NF}')
		show_progress success "gum already installed (${current_version})"
		return 0
	fi

	# Get version from packages.yaml or use default
	local version="${TOOL_VERSIONS[gum]:-0.17.0}"

	show_progress info "Installing gum ${version}..."

	# Determine architecture and package format
	local arch pkg_format
	pkg_format=$(_get_custom_pkg_format)
	arch=$(get_deb_arch) || {
		add_install_warning "Unsupported architecture for gum: $(uname -m)"
		return 1
	}

	# For rpm, architecture naming differs
	local rpm_arch="$arch"
	if [[ "$pkg_format" == "rpm" ]]; then
		rpm_arch=$(get_rpm_arch)
	fi

	local package_name gum_url gum_pkg
	if [[ "$pkg_format" == "deb" ]]; then
		package_name="gum_${version}_${arch}.deb"
	else
		package_name="gum-${version}.${rpm_arch}.rpm"
	fi
	gum_url="${DEVBASE_URL_GUM_RELEASES}/v${version}/${package_name}"
	gum_pkg="${_DEVBASE_TEMP}/${package_name}"

	# Get checksum for verification
	local gum_checksum
	if ! gum_checksum=$(get_gum_checksum "$version" "$package_name"); then
		add_install_warning "Could not fetch gum checksum - continuing without verification"
		gum_checksum=""
	fi

	if ! download_with_cache "$gum_url" "$gum_pkg" "$package_name" "gum" "" "$gum_checksum"; then
		add_install_warning "gum download failed - skipping"
		return 1
	fi

	# Install the package
	if _install_pkg_file "$gum_pkg"; then
		show_progress success "gum installed (${version})"
	else
		show_progress error "gum installation failed"
		return 1
	fi

	return 0
}
