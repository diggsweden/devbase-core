# Cypress binary download configuration
# This file will be placed in ~/.config/fish/conf.d/
# Uses internal registry mirror (DEVBASE_REGISTRY_URL set by 00-registry.fish)

# Set Cypress download mirror (assumes Nexus-style path structure)
if test -n "$DEVBASE_REGISTRY_URL"
    set -gx CYPRESS_DOWNLOAD_MIRROR "$DEVBASE_REGISTRY_URL/repository/cypress-binaries-proxy"
end
