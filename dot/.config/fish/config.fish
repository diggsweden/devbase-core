# Disable Fish greeting message
set -g fish_greeting ''
# Add mise shims to PATH first (contains starship and other tools)
fish_add_path $HOME/.local/share/mise/shims
# Use shims to keep PATH clean (only adds one shims directory to PATH)
# Check for mise in multiple locations
if test -x /usr/bin/mise
    /usr/bin/mise activate fish --shims | source
else if test -x $HOME/.local/bin/mise
    $HOME/.local/bin/mise activate fish --shims | source
end

# Auto-add SSH key to agent
if functions -q ssh-agent-init
    ssh-agent-init
end

# Starship prompt
starship init fish | source

# Optional: GOPATH for Go development
type -q go; and set -gx GOPATH $HOME/go; and fish_add_path $GOPATH/bin

# Update check
if status is-interactive; and functions -q devbase-update-nag
    devbase-update-nag
end

# Update Zellij clipboard config based on environment
if status is-interactive; and functions -q update-zellij-clipboard
    update-zellij-clipboard
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
