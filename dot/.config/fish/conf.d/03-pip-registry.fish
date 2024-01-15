# Python pip registry configuration
# This file will be placed in ~/.config/fish/conf.d/
# Uses internal PyPI proxy if DEVBASE_REGISTRY_URL is configured
# SSL verification uses system certificates

# Skip if no registry configured
if test -z "$DEVBASE_REGISTRY_URL"
    exit 0
end

# Set pip registry (assumes Nexus-style path structure)
set -gx PIP_INDEX_URL "$DEVBASE_REGISTRY_URL/repository/pypi-proxy/simple"
set -gx PIP_INDEX "$DEVBASE_REGISTRY_URL/repository/pypi-all/pypi"
set -gx PIP_REPOSITORY "$DEVBASE_REGISTRY_URL/repository/pypi-internal/"
