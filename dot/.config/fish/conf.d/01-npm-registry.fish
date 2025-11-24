# NPM registry configuration
# This file will be placed in ~/.config/fish/conf.d/
# NPM_CONFIG_REGISTRY should be set by custom config if needed

# Pass through NPM_CONFIG_REGISTRY if already set
if test -n "$NPM_CONFIG_REGISTRY"
    set -gx NPM_CONFIG_REGISTRY "$NPM_CONFIG_REGISTRY"
end
