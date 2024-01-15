function ssh-agent-init --description "Auto-add SSH key to agent if not already loaded"
    # Check if ssh-agent is running and has no keys
    if test (ssh-add -l 2>&1) = "The agent has no identities."
        # Try to add the devbase key silently
        ssh-add $HOME/.ssh/id_ed25519_devbase 2>/dev/null
    end
end