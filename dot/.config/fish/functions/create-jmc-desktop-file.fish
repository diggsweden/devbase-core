function create-jmc-desktop-file --description "Create desktop file for JDK Mission Control"
    set -l jmc_dir "$HOME/.local/share/JDK Mission Control"
    set -l jmc_bin "$jmc_dir/jmc"
    set -l desktop_file "$HOME/.local/share/applications/jmc.desktop"
    
    # Check if JMC is installed
    if not test -f "$jmc_bin"
        echo "✗ JDK Mission Control not found at: $jmc_dir" >&2
        echo "  Install JMC first, then run this command again." >&2
        return 1
    end
    
    # Determine icon path
    set -l jmc_icon "$jmc_dir/icon.xpm"
    if not test -f "$jmc_icon"
        # Fallback to generic Java icon
        set jmc_icon "java"
    end
    
    # Create desktop file
    mkdir -p "$HOME/.local/share/applications"
    
    cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JDK Mission Control
GenericName=Java Profiler
Comment=Advanced Java profiling and diagnostics tool
Exec=$jmc_bin
Icon=$jmc_icon
Categories=Development;Java;Profiler;Debugger;
Terminal=false
StartupNotify=true
StartupWMClass=jmc
EOF
    
    if test $status -eq 0
        echo "✓ Desktop file created: $desktop_file"
        echo "  JDK Mission Control should now appear in your application menu"
        
        # Update desktop database if available
        if command -v update-desktop-database >/dev/null 2>&1
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
            echo "✓ Desktop database updated"
        end
    else
        echo "✗ Failed to create desktop file" >&2
        return 1
    end
end
