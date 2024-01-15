# Testcontainers registry configuration
# This file will be placed in ~/.config/fish/conf.d/
# Uses internal container registry if DEVBASE_CONTAINERS_REGISTRY is configured

# Set Testcontainers registry prefix
if test -n "$DEVBASE_CONTAINERS_REGISTRY"
    set -gx TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX "$DEVBASE_CONTAINERS_REGISTRY/"
end
