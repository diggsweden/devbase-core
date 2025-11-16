function __ssh_agent_init --description "Auto-add devbase SSH key to agent if not already loaded"
    # Find devbase SSH key (try common patterns)
    set -l devbase_key ""
    for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f $HOME/.ssh/$key_pattern
            set devbase_key $HOME/.ssh/$key_pattern
            break
        end
    end
    
    # Silently skip if no devbase key found
    if test -z "$devbase_key"
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

    # Get fingerprint of devbase key
    set -l key_fingerprint (ssh-keygen -lf $devbase_key 2>/dev/null | awk '{print $2}')
    
    # Check if this specific key is already loaded
    if test -n "$key_fingerprint"
        if not ssh-add -l 2>/dev/null | string match -q "*$key_fingerprint*"
            # Add the devbase key silently (only show output on error)
            if not ssh-add $devbase_key 2>&1
                echo "Warning: Failed to add SSH key to agent" >&2
                return 1
            end
        end
    end
end