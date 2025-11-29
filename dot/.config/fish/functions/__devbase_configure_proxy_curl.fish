# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

#!/usr/bin/env fish
# Configure curl for better proxy compatibility when proxy is detected
# This internal function is called automatically from config.fish

function __devbase_configure_proxy_curl --description "Internal: Configure curl for proxy environments"
    # Check if any proxy is configured
    if set -q HTTP_PROXY; or set -q HTTPS_PROXY; or set -q http_proxy; or set -q https_proxy
        
        # Set environment variables for libcurl-based tools
        set -gx CURLOPT_FORBID_REUSE 1
        set -gx CURLOPT_FRESH_CONNECT 1
        
        # For wget compatibility
        set -gx WGET_OPTIONS "--no-http-keep-alive"
        
        # Create an alias for curl with proxy-friendly options
        # This ensures all interactive curl commands use these options
        function curl --wraps curl --description "curl with proxy compatibility"
            command curl --no-keepalive --no-sessionid -H "Connection: close" $argv
        end
    end
end

# Call the function when this file is sourced
__devbase_configure_proxy_curl