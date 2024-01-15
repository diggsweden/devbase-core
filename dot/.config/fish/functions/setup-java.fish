# ~/.config/fish/conf.d/java-setup.fish
# Setup Java home and certificates for Mise-managed Java

# Mise automatically sets JAVA_HOME when Java is activated
# But we need to ensure certs are linked properly

function setup_java_certs --on-variable JAVA_HOME
    # Only run if JAVA_HOME is set and valid
    if test -n "$JAVA_HOME" -a -d "$JAVA_HOME"
        set -gx JDK_HOME $JAVA_HOME
        
        # Check if cacerts exists and is not already a symlink to system certs
        set -l java_cacerts "$JAVA_HOME/lib/security/cacerts"
        set -l system_cacerts "/etc/ssl/certs/java/cacerts"
        
        if test -f "$java_cacerts"
            # Check if it's not already linked to the right place
            if not test (readlink "$java_cacerts" 2>/dev/null) = "$system_cacerts"
                # Check if system certificates exist
                if test -f "$system_cacerts"
                    # Backup original if it exists and isn't a symlink
                    if test -f "$java_cacerts" -a ! -L "$java_cacerts"
                        if mv "$java_cacerts" "$java_cacerts.backup"
                            printf "Backed up original Java certificates\n"
                        else
                            printf "Warning: Could not backup Java certificates\n" >&2
                            return 1
                        end
                    end
                    # Create symlink to system certificates
                    if ln -sf "$system_cacerts" "$java_cacerts"
                        printf "Linked Java certificates to system certificates\n"
                    else
                        printf "Warning: Could not link Java certificates\n" >&2
                        return 1
                    end
                else
                    printf "Warning: System certificates not found at %s\n" "$system_cacerts" >&2
                end
            end
        end
    end
end

# Run once at startup if JAVA_HOME is already set
if test -n "$JAVA_HOME"
    setup_java_certs
end