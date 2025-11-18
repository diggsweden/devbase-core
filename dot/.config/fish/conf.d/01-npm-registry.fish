# NPM registry configuration
# This file will be placed in ~/.config/fish/conf.d/
# Uses internal registry (DEVBASE_REGISTRY_URL set by 00-registry.fish)

# Set NPM registry (assumes Nexus-style path structure)
if test -n "$DEVBASE_REGISTRY_URL"
    set -gx NPM_CONFIG_REGISTRY "$DEVBASE_REGISTRY_URL/repository/npmjs/"
end
