function setup-intellij-vmoptions --description "Apply optimized VM options to all installed IntelliJ IDEA versions"
    set -l template "$HOME/.config/devbase/intellij-vmoptions.template"
    
    # Check if template exists
    if not test -f "$template"
        echo "✗ Template not found: $template" >&2
        return 1
    end
    
    # Find all IntelliJ IDEA config directories
    set -l config_dirs (find "$HOME/.config/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" 2>/dev/null)
    
    if test (count $config_dirs) -eq 0
        echo "✗ No IntelliJ IDEA installations found in ~/.config/JetBrains/" >&2
        echo "  Install IntelliJ IDEA first, then run this command again." >&2
        return 1
    end
    
    set -l applied_count 0
    
    for config_dir in $config_dirs
        set -l vmoptions_file "$config_dir/idea64.vmoptions"
        set -l version_name (basename "$config_dir")
        
        # Check if we're on Wayland
        if test "$XDG_SESSION_TYPE" = "wayland"; or test -n "$WAYLAND_DISPLAY"
            # Enable Wayland support
            sed 's|# WAYLAND_PLACEHOLDER|-Dawt.toolkit.name=WLToolkit|' "$template" > "$vmoptions_file"
            echo "✓ $version_name: VM options applied (Wayland enabled)"
        else
            # Remove Wayland placeholder
            sed '/# WAYLAND_PLACEHOLDER/d' "$template" > "$vmoptions_file"
            echo "✓ $version_name: VM options applied"
        end
        
        set applied_count (math $applied_count + 1)
    end
    
    if test $applied_count -gt 0
        echo ""
        echo "Applied optimized VM options to $applied_count IntelliJ installation(s)"
        echo "Settings: Xmx=4GB, optimized for medium-sized projects"
        echo ""
        echo "Restart IntelliJ IDEA for changes to take effect."
    end
end
