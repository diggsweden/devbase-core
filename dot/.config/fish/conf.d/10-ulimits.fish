# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# ~/.config/fish/conf.d/10-ulimits.fish
# Set development-friendly resource limits

function setup_ulimits --description "Set development resource limits"
    # File descriptors - needed for development tools, IDEs, containers
    ulimit -n 70000 2>/dev/null
    
    # File size - unlimited for logs, dumps, builds
    ulimit -f unlimited 2>/dev/null
    
    # Core dump size - useful for debugging
    ulimit -c unlimited 2>/dev/null
    
    # Max user processes - for containers and build tools
    ulimit -u 32768 2>/dev/null
    
    # Virtual memory - unlimited for development
    ulimit -v unlimited 2>/dev/null
end

# Run on shell startup
if status is-interactive
    setup_ulimits
end
