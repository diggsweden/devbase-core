# Check and fix Java certificates on shell startup
# This ensures new Java versions installed by mise use system certificates

if status is-interactive
    # Check if any Java installations need certificate fixing
    set -l java_dir "$HOME/.local/share/mise/installs/java"
    set -l needs_fix false
    
    if test -d $java_dir
        for java_version in $java_dir/*
            if test -d $java_version
                set -l cacerts "$java_version/lib/security/cacerts"
                # Check if it's a regular file (not a symlink)
                if test -f $cacerts -a ! -L $cacerts
                    set needs_fix true
                    break
                end
            end
        end
    end
    
    # Run fix script if needed
    if test $needs_fix = true
        set -l fix_script "$HOME/devbase-custom-config/hooks/fix-java-cacerts.sh"
        if test -x $fix_script
            $fix_script >/dev/null 2>&1
        end
    end
end