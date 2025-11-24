# Cypress binary download configuration
# Uses DEVBASE_REGISTRY_URL set by 00-registry.fish
# Custom config can override this file to set organization-specific paths

if test -n "$DEVBASE_REGISTRY_URL"
    set -gx CYPRESS_DOWNLOAD_MIRROR "$DEVBASE_REGISTRY_URL/"
end
