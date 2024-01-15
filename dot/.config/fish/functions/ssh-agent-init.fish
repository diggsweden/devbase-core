function ssh-agent-init --description "Auto-add devbase SSH key to agent if not already loaded"
    # Check if devbase SSH key exists
    if not test -f $HOME/.ssh/id_ecdsa_nistp521_devbase
        # Silently skip if key doesn't exist (might be using different key or no SSH setup)
        return 0
    end

    # Check if SSH agent is running and accessible
    ssh-add -l &>/dev/null
    set -l exit_code $status
    
    if test $exit_code -eq 2
        # Agent is not running
        echo "Warning: SSH agent is not running" >&2
        
        # Check if systemd service exists
        if test -f $HOME/.config/systemd/user/ssh-agent.service
            echo "  Start with: systemctl --user start ssh-agent.service" >&2
            echo "  Enable at boot: systemctl --user enable ssh-agent.service" >&2
        else
            echo "  On native Linux, your desktop environment typically manages this." >&2
            echo "  Otherwise, start manually: eval \$(ssh-agent -s)" >&2
        end
        return 1
    end

    # Check if a 521-bit ECDSA key is already loaded (devbase default)
    if not ssh-add -l 2>/dev/null | string match -q "*521*ECDSA*"
        # Add the devbase key silently (only show output on error)
        if not ssh-add $HOME/.ssh/id_ecdsa_nistp521_devbase 2>&1
            echo "Warning: Failed to add SSH key to agent" >&2
            return 1
        end
    end
end