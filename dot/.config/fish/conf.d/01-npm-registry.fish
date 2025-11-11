# NPM registry configuration
# This file will be placed in ~/.config/fish/conf.d/
# Uses internal registry if DEVBASE_REGISTRY_URL is configured

# Set NPM registry (assumes Nexus-style path structure)
if test -n "$DEVBASE_REGISTRY_URL"
    set -gx NPM_CONFIG_REGISTRY "$DEVBASE_REGISTRY_URL/repository/npmjs/"
end
