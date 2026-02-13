#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Centralized external URLs and constants
# All hardcoded download/API URLs in one place for easy auditing and updates

set -uo pipefail

# =============================================================================
# MISE (TOOL VERSION MANAGER)
# =============================================================================
readonly DEVBASE_URL_MISE_INSTALLER="https://mise.run"
readonly DEVBASE_URL_MISE_RELEASES="https://github.com/jdx/mise/releases/download"

# =============================================================================
# MOZILLA FIREFOX
# =============================================================================
readonly DEVBASE_URL_MOZILLA_GPG_KEY="https://packages.mozilla.org/apt/repo-signing-key.gpg"
readonly DEVBASE_URL_MOZILLA_APT_REPO="https://packages.mozilla.org/apt"

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================
readonly DEVBASE_URL_VSCODE_SHA_API="https://code.visualstudio.com/sha"
readonly DEVBASE_URL_VSCODE_DOWNLOAD="https://update.code.visualstudio.com"
readonly DEVBASE_URL_JETBRAINS_DOWNLOAD="https://download.jetbrains.com/idea"
readonly DEVBASE_URL_OCP_MIRROR="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
readonly DEVBASE_URL_GUM_RELEASES="https://github.com/charmbracelet/gum/releases/download"

# =============================================================================
# GITHUB-HOSTED TOOLS
# =============================================================================
readonly DEVBASE_URL_JMC_RELEASES="https://github.com/adoptium/jmc-build/releases/download"
readonly DEVBASE_URL_DBEAVER_RELEASES="https://github.com/dbeaver/dbeaver/releases/download"
readonly DEVBASE_URL_KSE_RELEASES="https://github.com/kaikramer/keystore-explorer/releases/download"
readonly DEVBASE_URL_NERD_FONTS_RELEASES="https://github.com/ryanoasis/nerd-fonts/releases/download"
readonly DEVBASE_URL_K3S_RAW="https://raw.githubusercontent.com/k3s-io/k3s"

# =============================================================================
# GIT REPOSITORIES
# =============================================================================
readonly DEVBASE_URL_LAZYVIM_STARTER="https://github.com/LazyVim/starter"
readonly DEVBASE_URL_FISHER_REPO="https://github.com/jorgebucaran/fisher.git"

# =============================================================================
# FLATPAK
# =============================================================================
readonly DEVBASE_URL_FLATHUB_REPO="https://dl.flathub.org/repo/flathub.flatpakrepo"

# =============================================================================
# NETWORK CONNECTIVITY TEST SITES
# =============================================================================
readonly DEVBASE_CONNECTIVITY_TEST_SITES=("https://github.com" "https://google.com" "https://codeberg.org")
