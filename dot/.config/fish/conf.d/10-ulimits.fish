# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# ~/.config/fish/conf.d/10-ulimits.fish
# Set development-friendly resource limits

# Only core dumps are set here. File descriptors and processes come from
# /etc/security/limits.d/99-devbase.conf, and `ulimit -n`/`-u` without -S
# would lower the hard limit for the whole session, which cannot be undone.
# File size and virtual memory are unlimited by default already.
function setup_ulimits --description "Set development resource limits"
    # Core dump size - useful for debugging, disabled by default
    ulimit -c unlimited 2>/dev/null
end

# Run on shell startup
if status is-interactive
    setup_ulimits
end
