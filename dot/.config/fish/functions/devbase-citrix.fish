# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-citrix - Download and install Citrix Workspace App for Linux
# Downloads .deb packages from Citrix and installs them

set -g __citrix_download_dir "/tmp/citrix-install"
set -g __citrix_download_page "https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"

# Citrix Workspace App version - update via Renovate or manually
# renovate: datasource=custom.citrix depName=citrix-workspace
set -g __citrix_version "25.08.10.111"

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

function __citrix_cleanup
    if test -d "$__citrix_download_dir"
        rm -rf "$__citrix_download_dir"
    end
end

function __citrix_fetch_download_urls --description "Fetch download URLs from Citrix page"
    # Citrix downloads require time-limited tokens, so we must scrape the page
    set -l page_content (curl -sL "$__citrix_download_page" 2>/dev/null)
    
    if test -z "$page_content"
        return 1
    end
    
    # Extract URLs with tokens for amd64 packages
    set -l icaclient_url (echo "$page_content" | string match -r 'downloads\.citrix\.com/[0-9]+/icaclient_[0-9.]+_amd64\.deb[^"]*' | head -1)
    set -l ctxusb_url (echo "$page_content" | string match -r 'downloads\.citrix\.com/[0-9]+/ctxusb_[0-9.]+_amd64\.deb[^"]*' | head -1)
    
    if test -z "$icaclient_url"
        return 1
    end
    
    echo "https://$icaclient_url"
    test -n "$ctxusb_url"; and echo "https://$ctxusb_url"
end

function __citrix_get_static_urls --description "Get static URLs (for display/testing)"
    # Static URLs without tokens (for --check display)
    echo "https://downloads.citrix.com/*/icaclient_"$__citrix_version"_amd64.deb"
    echo "https://downloads.citrix.com/*/ctxusb_"$__citrix_version"_amd64.deb"
end

function __citrix_get_version --description "Get current pinned version"
    echo "$__citrix_version"
end

function __citrix_download_file --description "Download a file"
    set -l url $argv[1]
    set -l dest $argv[2]
    
    curl -sL -o "$dest" "$url"
end

function __citrix_install_deb --description "Install .deb package with apt"
    set -l deb_file $argv[1]
    set -l filename (basename "$deb_file")
    
    __citrix_print_info "Installing $filename..."
    
    if sudo apt install -y "$deb_file" 2>&1 | tail -5
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
    echo "  1. Download latest Citrix Workspace App .deb packages"
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
    if not command -q curl
        __citrix_print_error "curl is required but not installed"
        return 1
    end
    
    echo ""
    echo "Citrix Workspace App Installer"
    echo "==============================="
    echo ""
    
    # Create temp directory
    mkdir -p "$__citrix_download_dir"
    
    # Fetch download URLs with tokens
    __citrix_print_info "Fetching download URLs from Citrix..."
    set -l urls (__citrix_fetch_download_urls)
    
    if test $status -ne 0 -o -z "$urls"
        __citrix_print_error "Failed to fetch download URLs from Citrix"
        __citrix_cleanup
        return 1
    end
    
    set -l citrix_ver (__citrix_get_version)
    __citrix_print_info "Installing Citrix Workspace App version $citrix_ver..."
    
    # Download and install each package
    for url in $urls
        set -l filename (basename (echo "$url" | string split '?' | head -1))
        set -l filepath "$__citrix_download_dir/$filename"
        
        __citrix_print_info "Downloading $filename..."
        
        if not __citrix_download_file "$url" "$filepath"
            __citrix_print_error "Failed to download $filename"
            __citrix_cleanup
            return 1
        end
        
        __citrix_print_success "Downloaded $filename"
        
        if not __citrix_install_deb "$filepath"
            __citrix_cleanup
            return 1
        end
    end
    
    # Cleanup
    __citrix_cleanup
    
    echo ""
    __citrix_print_success "Citrix Workspace App installed successfully!"
    echo ""
    __citrix_print_info "For smart card support, enable pcscd:"
    echo "  sudo systemctl enable --now pcscd"
    echo ""
    
    return 0
end
