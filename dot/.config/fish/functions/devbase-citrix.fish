# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-citrix - Download and install Citrix Workspace App for Linux
# Downloads .deb packages from Citrix and installs them

set -g __citrix_download_page "https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"

# Citrix Workspace App version - update via Renovate or manually
# renovate: datasource=custom.citrix depName=citrix-workspace
set -g __citrix_version "26.04.10.1"

function __citrix_print_info
    printf "%sⓘ%s %s\n" (set_color cyan) (set_color normal) "$argv[1]"
end

function __citrix_print_success
    printf "%s✓%s %s\n" (set_color green) (set_color normal) "$argv[1]"
end

function __citrix_print_warning
    printf "%s‼%s %s\n" (set_color yellow) (set_color normal) "$argv[1]"
end

function __citrix_print_error
    printf "%s✗%s %s\n" (set_color red) (set_color normal) "$argv[1]" >&2
end

function __citrix_fetch_download_urls --description "Fetch pinned download URLs and SHA-256 digests"
    # Citrix downloads require time-limited tokens, so we must scrape the page
    set -l page_content (curl --fail --silent --show-error --location \
        --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
        "$__citrix_download_page")
    or return 1

    # Associate each anchor with the checksum in its own download entry.
    # A changed page layout or missing pinned release must fail closed.
    # Flatten HTML source lines before splitting entries: Fish also splits command
    # substitutions at newlines, which would separate anchors from their hashes.
    set -l entries (string split '<div class="ctx-download-entry">' -- (string join ' ' -- $page_content))
    set -l pinned_version (string escape --style=regex "$__citrix_version")
    for package in icaclient ctxusb
        set -l found false
        for name in $package $package-gcc-8
            for entry in $entries[2..-1]
                set -l url (string match --groups-only --regex \
                    'rel="//(downloads\.citrix\.com/[0-9]+/'$name'_'$pinned_version'_amd64\.deb\?[^"[:space:]]+)"' -- "$entry")
                test (count $url) -eq 1; or continue
                set -l checksum (string match --all --groups-only --regex 'SHA-256\s*-\s*([a-fA-F0-9]{64})\b' -- "$entry")
                test (count $checksum) -eq 1; or return 1
                printf 'https://%s\t%s\n' (string replace --all '&amp;' '&' -- "$url") "$checksum"
                set found true
                break
            end
            test "$found" = true; and break
        end
        # USB redirection is optional, but the main app is required.
        if test "$package" = icaclient; and test "$found" != true
            return 1
        end
    end
    return 0
end

function __citrix_get_static_urls --description "Get static URLs (for display/testing)"
    # Static URLs without tokens (for --check display)
    echo "https://downloads.citrix.com/*/icaclient_"$__citrix_version"_amd64.deb"
    echo "https://downloads.citrix.com/*/icaclient-gcc-8_"$__citrix_version"_amd64.deb"
    echo "https://downloads.citrix.com/*/ctxusb_"$__citrix_version"_amd64.deb"
    echo "https://downloads.citrix.com/*/ctxusb-gcc-8_"$__citrix_version"_amd64.deb"
end

function __citrix_get_version --description "Get current pinned version"
    echo "$__citrix_version"
end

function __citrix_download_file --description "Download a file"
    set -l url $argv[1]
    set -l dest $argv[2]
    
    curl --fail --location --show-error --progress-bar \
        --proto '=https' --proto-redir '=https' \
        --retry 2 --connect-timeout 10 --max-time 900 \
        -o "$dest" "$url"
    or return 1

    test -s "$dest"
end

function __citrix_prompt_yn --description "Prompt user for yes/no with default"
    set -l prompt $argv[1]
    set -l default $argv[2]
    set -l prompt_text

    if test "$default" = "y"
        set prompt_text "$prompt [Y/n]: "
    else
        set prompt_text "$prompt [y/N]: "
    end


    read -l -P "$prompt_text" response

    if test -z "$response"
        set response "$default"
    end

    string match -qi 'y*' "$response"
end

function __citrix_configure_install_options --description "Prompt user for Citrix install options"
    echo ""
    __citrix_print_info "Citrix installation options:"
    echo ""
    
    # App Protection (default: No)
    if __citrix_prompt_yn "  Enable App Protection (anti-keylogging/screenshot protection)?" "n"
        set -g __citrix_app_protection "yes"
    else
        set -g __citrix_app_protection "no"
    end
    
    # Device Trust (default: No)
    
    set -l dt_response
    while true
        read -l -P "  Enable Device Trust (endpoint compliance checking)? [y/N]: " dt_response
        or return 1
        if test -z "$dt_response"
            set dt_response "n"
        end
        string match -qri '^[yn]' "$dt_response"; and break
    end
    
    if string match -qi 'y*' "$dt_response"
        set -g __citrix_device_trust "yes"
    else
        set -g __citrix_device_trust "no"
    end
    
    echo ""
end

function __citrix_install_deb --description "Install .deb package with apt"
    set -l deb_file $argv[1]
    set -l filename (basename "$deb_file")
    
    __citrix_print_info "Installing $filename..."
    
    # Pre-configure Citrix options for non-interactive install
    if string match -q '*icaclient*' "$filename"
        # EULA acceptance (always accept) - required
        echo "icaclient icaclient/accepteula select accept" | sudo debconf-set-selections
        or return 1
        # App Protection (yes/no)
        echo "icaclient app_protection/install_app_protection select $__citrix_app_protection" | sudo debconf-set-selections
        or return 1
        # Device Trust (yes/no) - added in version 2503/25.03
        # Try both possible key formats
        echo "icaclient app_protection/install_device_trust select $__citrix_device_trust" | sudo debconf-set-selections 2>/dev/null
        or return 1
        echo "icaclient icaclient/install_device_trust select $__citrix_device_trust" | sudo debconf-set-selections 2>/dev/null
        or return 1
    end
    
    if sudo DEBIAN_FRONTEND=noninteractive apt install -y "$deb_file"
        __citrix_print_success "Installed $filename"
        return 0
    else
        __citrix_print_error "Failed to install $filename"
        return 1
    end
end

function __citrix_usage --description "Show usage information"
    echo "Usage: devbase-citrix [OPTION]"
    echo ""
    echo "Download and install Citrix Workspace App for Linux."
    echo ""
    echo "Options:"
    echo "  --check     Show available version without installing"
    echo "  --help      Show this help message"
    echo ""
    echo "This command will:"
    echo "  1. Download and verify pinned Citrix Workspace App .deb packages"
    echo "  2. Install icaclient (main app) and ctxusb (USB redirection)"
    echo ""
    echo "After installation, enable pcscd for smart card support:"
    echo "  sudo systemctl enable --now pcscd"
end

function __citrix_check_version --description "Show pinned version"
    set -l citrix_ver (__citrix_get_version)
    
    __citrix_print_success "Pinned version: $citrix_ver"
    echo ""
    echo "Packages:"
    echo "  icaclient_"$citrix_ver"_amd64.deb"
    echo "  ctxusb_"$citrix_ver"_amd64.deb"
    echo ""
    __citrix_print_info "Version is updated via Renovate or manually in devbase-citrix.fish"
end

function __citrix_download_and_install --description "Verify all packages before installing"
    set -l download_dir $argv[1]
    __citrix_print_info "Fetching pinned packages and checksums from Citrix..."
    set -l downloads (__citrix_fetch_download_urls)
    or begin
        __citrix_print_error "Pinned Citrix packages or checksums are unavailable"
        return 1
    end

    set -l files
    for download in $downloads
        set -l fields (string split \t -- "$download")
        set -l filename (path basename (string split '?' -- $fields[1])[1])
        set -l filepath "$download_dir/$filename"
        __citrix_print_info "Downloading $filename..."
        if not __citrix_download_file "$fields[1]" "$filepath"
            __citrix_print_error "Failed to download $filename"
            return 1
        end
        if not printf '%s  %s\n' "$fields[2]" "$filepath" | sha256sum --check --status
            __citrix_print_error "Checksum verification failed for $filename"
            return 1
        end
        set -l package (string split '_' -- "$filename")[1]
        set package (string replace '-gcc-8' '' -- "$package")
        set -l actual_package (dpkg-deb --field "$filepath" Package); or return 1
        set -l actual_version (dpkg-deb --field "$filepath" Version); or return 1
        set -l actual_arch (dpkg-deb --field "$filepath" Architecture); or return 1
        if test "$actual_package" != "$package"; or test "$actual_arch" != amd64; or not dpkg --compare-versions "$actual_version" eq "$__citrix_version"
            __citrix_print_error "Unexpected package identity, version or architecture: $filename"
            return 1
        end
        set -a files "$filepath"
    end
    test (count $files) -gt 0; or return 1
    for file in $files
        __citrix_install_deb "$file"; or return 1
    end
end

function devbase-citrix --description "Download and install Citrix Workspace App"
    switch "$argv[1]"
        case --help -h
            __citrix_usage
            return 0
        case --check -c
            __citrix_check_version
            return $status
        case ''
            # Continue with installation
        case '*'
            __citrix_print_error "Unknown option: $argv[1]"
            __citrix_usage
            return 1
    end
    
    # Check if running on Linux
    if not test (uname) = "Linux"
        __citrix_print_error "This command only works on Linux"
        return 1
    end
    
    # Check for required tools
    for tool in curl sha256sum dpkg dpkg-deb
        if not command -q $tool
            __citrix_print_error "$tool is required but not installed"
            return 1
        end
    end
    set -l architecture (dpkg --print-architecture); or return 1
    if test "$architecture" != amd64
        __citrix_print_error "This installer requires Debian/Ubuntu amd64"
        return 1
    end
    
    echo ""
    echo "Citrix Workspace App Installer"
    echo "==============================="
    
    # Prompt user for installation options
    __citrix_configure_install_options
    or return 1
    
    # mktemp creates a private directory; never reuse or delete a shared path.
    set -l download_dir (mktemp -d /tmp/devbase-citrix.XXXXXXXXXX)
    if test $status -ne 0; or test -z "$download_dir"
        __citrix_print_error "Failed to create a private download directory"
        return 1
    end
    __citrix_download_and_install "$download_dir"
    set -l result $status
    rm -rf -- "$download_dir"
    test $result -eq 0; or return $result
    
    echo ""
    __citrix_print_success "Citrix Workspace App installed successfully!"
    echo ""
    __citrix_print_info "For smart card support, enable pcscd:"
    echo "  sudo systemctl enable --now pcscd"
    echo ""
    
    return 0
end
