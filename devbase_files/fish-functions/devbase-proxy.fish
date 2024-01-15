# ~/.config/fish/functions/devbase-proxy.fish
# Proxy management functions for corporate environment

function devbase-proxy --description "Manage proxy settings: devbase-proxy [on|off|status]"
    set -l action status
    if test (count $argv) -gt 0
        set action $argv[1]
    end
    
    switch $action
        case on enable
            _proxy_enable
        case off disable  
            _proxy_disable
        case status
            _proxy_status
        case '*'
            printf "Usage: devbase-proxy [on|off|status]\n"
            printf "  on     - Enable proxy settings\n"
            printf "  off    - Disable proxy settings\n"  
            printf "  status - Show current proxy status\n"
    end
end

function _proxy_enable --description "Enable all proxy settings"
    # Use organization proxy settings from environment
    # Falls back to environment variables or empty if not configured
    set -l proxy_url "$DEVBASE_PROXY_URL"
    
    # Check if proxy URL is configured
    if test -z "$proxy_url"
        if test -n "$HTTP_PROXY"
            set proxy_url "$HTTP_PROXY"
        else
            printf "Error: No proxy configured (set DEVBASE_PROXY_URL or HTTP_PROXY)\n"
            return 1
        end
    end
    
    # Use organization no_proxy or default
    set -l no_proxy "$DEVBASE_NO_PROXY_DOMAINS"
    if test -z "$no_proxy"
        if test -n "$NO_PROXY"
            set no_proxy "$NO_PROXY"
        else
            set no_proxy "localhost,127.0.0.1"
        end
    end
    
    printf "Enabling proxy settings...\n"
    
    # Set environment variables
    set -gx HTTP_PROXY $proxy_url
    set -gx http_proxy $proxy_url
    set -gx HTTPS_PROXY $proxy_url  
    set -gx https_proxy $proxy_url
    set -gx NO_PROXY $no_proxy
    set -gx no_proxy $no_proxy
    
    # Configure APT proxy
    _proxy_configure_apt $proxy_url
    
    # Configure Snap proxy
    _proxy_configure_snap $proxy_url
    
    printf "Proxy settings enabled\n"
end

function _proxy_disable --description "Disable all proxy settings"
    printf "Disabling proxy settings...\n"
    
    # Unset environment variables
    set -e HTTP_PROXY
    set -e http_proxy  
    set -e HTTPS_PROXY
    set -e https_proxy
    set -e NO_PROXY
    set -e no_proxy
    
    # Disable APT proxy
    _proxy_configure_apt ""
    
    # Disable Snap proxy
    _proxy_configure_snap ""
    
    printf "Proxy settings disabled\n"
end

function _proxy_status --description "Show current proxy status"
    if test -n "$HTTP_PROXY"
        printf "Proxy: ENABLED\n"
        printf "  HTTP_PROXY: %s\n" "$HTTP_PROXY"
        printf "  NO_PROXY: %s\n" "$NO_PROXY"
    else
        printf "Proxy: DISABLED\n"
    end
end

function _proxy_configure_apt --argument proxy_url --description "Configure APT proxy settings"
    set -l apt_file "/etc/apt/apt.conf.d/90proxy.conf"
    
    if test -n "$proxy_url"
        # Enable APT proxy
        if not test -f "$apt_file"
            if printf "Acquire::http::Proxy \"%s\";\n" "$proxy_url" | sudo tee -a "$apt_file" >/dev/null
                printf "Acquire::https::Proxy \"%s\";\n" "$proxy_url" | sudo tee -a "$apt_file" >/dev/null
            else
                printf "Warning: Failed to configure APT proxy\n" >&2
            end
        end
    else
        # Disable APT proxy
        if not printf '#...\n' | sudo tee "$apt_file" >/dev/null
            printf "Warning: Failed to disable APT proxy\n" >&2
        end
    end
end

function _proxy_configure_snap --argument proxy_url --description "Configure Snap proxy settings"
    if not type -q snap
        return 0  # Skip if snap not installed
    end
    
    if test -n "$proxy_url"
        # Enable Snap proxy  
        if not sudo snap set system proxy.http="$proxy_url" 2>/dev/null
            printf "Warning: Failed to set snap HTTP proxy\n" >&2
        end
        if not sudo snap set system proxy.https="$proxy_url" 2>/dev/null
            printf "Warning: Failed to set snap HTTPS proxy\n" >&2
        end
    else
        # Disable Snap proxy
        if not sudo snap set system proxy.http="" 2>/dev/null
            printf "Warning: Failed to unset snap HTTP proxy\n" >&2
        end
        if not sudo snap set system proxy.https="" 2>/dev/null
            printf "Warning: Failed to unset snap HTTPS proxy\n" >&2
        end
    end
end