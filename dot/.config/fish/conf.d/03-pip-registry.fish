# Python pip registry configuration
# Uses DEVBASE_REGISTRY_URL_NPM set by 00-registry.fish
# Custom config can override this file to set organization-specific paths

if test -n "$DEVBASE_REGISTRY_URL_NPM"
    set -gx PIP_INDEX_URL "$DEVBASE_REGISTRY_URL_NPM/"
end
