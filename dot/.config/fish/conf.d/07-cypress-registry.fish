# Cypress binary download configuration
# This file will be placed in ~/.config/fish/conf.d/
# CYPRESS_DOWNLOAD_MIRROR should be set by custom config if needed

# Pass through CYPRESS_DOWNLOAD_MIRROR if already set
if test -n "$CYPRESS_DOWNLOAD_MIRROR"
    set -gx CYPRESS_DOWNLOAD_MIRROR "$CYPRESS_DOWNLOAD_MIRROR"
end
