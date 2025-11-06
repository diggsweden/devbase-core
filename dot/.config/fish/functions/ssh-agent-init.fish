function ssh-agent-init --description "Auto-add devbase SSH key to agent if not already loaded"
    # Check if devbase SSH key exists
    if not test -f $HOME/.ssh/id_ed25519_devbase
        return 0
    end

    # Check if the devbase key is already loaded in the agent
    if not ssh-add -l 2>/dev/null | string match -q "*id_ed25519_devbase*"
        # Add the devbase key silently
        ssh-add $HOME/.ssh/id_ed25519_devbase 2>/dev/null
    end
end