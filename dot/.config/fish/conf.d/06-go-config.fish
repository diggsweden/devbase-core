# Go configuration - Minimal setup for Digg environment
# This file will be placed in ~/.config/fish/conf.d/

# Fix incorrect GOBIN if it points to mise's internal directory
# Set GOBIN to ~/.local/bin for go install commands
if string match -q "*/mise/installs/go/*" "$GOBIN"
    set -gx GOBIN $HOME/.local/bin
else if not set -q GOBIN
    set -gx GOBIN $HOME/.local/bin
end



# Go proxy and certificate handling:
# a) Go DOES respect HTTP_PROXY/HTTPS_PROXY environment variables automatically
# b) Go DOES NOT use system certificates by default - it has its own bundle
#    However, on Linux it reads from standard locations including /etc/ssl/certs/
# c) GOBIN is set to ~/.local/bin (already in PATH via devbase)

# If Digg has a Go module proxy, uncomment and configure:
# if test -n "$DEVBASE_REGISTRY_URL"
#     set -gx GOPROXY "$DEVBASE_REGISTRY_URL/repository/go-proxy"
#     set -gx GONOSUMDB "*.digg.se,*.sgit.se"
#     set -gx GONOPROXY "*.digg.se,*.sgit.se"
# end