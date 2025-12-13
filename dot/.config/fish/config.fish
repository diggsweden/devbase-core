# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Disable Fish greeting message
set -g fish_greeting ''
# Activate mise without --shims to avoid shim hangs in VSCode extensions
# This adds all tool directories directly to PATH (including aqua tools)
if test -x /usr/bin/mise
    /usr/bin/mise activate fish | source
else if test -x $HOME/.local/bin/mise
    $HOME/.local/bin/mise activate fish | source
end

# Auto-add SSH key to agent (only in interactive shells)
if status is-interactive; and functions -q __ssh_agent_init
    __ssh_agent_init
end

# Configure curl for proxy environments if needed
# The function is in ~/.config/fish/functions/ and will be autoloaded
# We just need to call it if proxy is set
if set -q HTTP_PROXY; or set -q HTTPS_PROXY; or set -q http_proxy; or set -q https_proxy
    __devbase_configure_proxy_curl
end

# Starship prompt
starship init fish | source

# Optional: GOPATH for Go development
type -q go; and set -gx GOPATH $HOME/go; and fish_add_path $GOPATH/bin

# Update check (prompts if update available on every shell start)
if status is-interactive; and functions -q __devbase_update_check
    __devbase_update_check
end

# Update Zellij clipboard config based on environment
if status is-interactive; and functions -q __update_zellij_clipboard
    __update_zellij_clipboard
end

# Auto-start Zellij (must be after mise activation)
if status is-interactive
    and test "$DEVBASE_ZELLIJ_AUTOSTART" = "true"
    and not set -q ZELLIJ
    and not set -q SSH_CLIENT
    and not set -q SSH_TTY
    and test "$TERM" != "linux"
    and command -q zellij
    
    if test "$ZELLIJ_AUTO_ATTACH" = "true"
        zellij attach -c
    else
        zellij
    end
    
    if test "$ZELLIJ_AUTO_EXIT" = "true"
        kill $fish_pid
    end
end
