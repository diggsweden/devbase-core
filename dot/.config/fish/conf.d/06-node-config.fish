# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Runs after 00-proxy.fish; also handles inherited proxy environment variables.
# Enable Node's built-in proxy support while preserving explicit settings (e.g. 0).
if not set -q NODE_USE_ENV_PROXY; and test -n "$HTTP_PROXY$HTTPS_PROXY$http_proxy$https_proxy"
    set -gx NODE_USE_ENV_PROXY 1
end
