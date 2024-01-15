# Quality checks and automation for devbase-core
# Run 'just' to see available commands

# Terminal colors
red := '\033[0;31m'
green := '\033[0;32m'
yellow := '\033[0;33m'
blue := '\033[0;34m'
nc := '\033[0m'

# Unicode symbols (works across platforms)
checkmark := '✓'
missing := '✗'
arrow := '→'

# Default recipe - show help
default:
    @printf "Available commands:\n"
    @just --list --unsorted | grep -v "default"

# Run all quality verifications with summary
verify: dev-tools-deps-verify
    @mise exec -- bash development/just/run-all-checks.sh

# Lint markdown files with rumdl
lint-markdown:
    @mise exec -- bash development/just/linters/markdown.sh check

# Lint YAML files with yamlfmt
lint-yaml:
    @mise exec -- bash development/just/linters/yaml.sh check

# Lint shell scripts with shellcheck
lint-shell:
    @mise exec -- bash development/just/linters/shell.sh

# Check shell script formatting with shfmt
lint-shell-fmt:
    @mise exec -- bash development/just/linters/shell-fmt.sh check

# Fix shell script formatting with shfmt
lint-shell-fmt-fix:
    @mise exec -- bash development/just/linters/shell-fmt.sh fix

# Lint GitHub Actions workflows with actionlint
lint-actions:
    @mise exec -- bash development/just/linters/github-actions.sh

# Check for secrets and sensitive data with gitleaks
lint-secrets:
    @mise exec -- bash development/just/linters/secrets.sh

# Validate commit messages with conform
lint-commit:
    @mise exec -- bash development/just/linters/commits.sh

# Fix all auto-fixable issues
lint-fix: lint-markdown-fix lint-yaml-fix lint-shell-fmt-fix
    @printf '{{green}}{{checkmark}} All auto-fixable issues resolved{{nc}}\n'
    @printf 'Note: Some issues may require manual fixes\n'

# Fix markdown issues with rumdl
lint-markdown-fix:
    @bash development/just/linters/markdown.sh fix

# Fix YAML formatting with yamlfmt
lint-yaml-fix:
    @bash development/just/linters/yaml.sh fix

# Verify required development tools are installed
dev-tools-deps-verify:
    @bash development/just/check-tools.sh

# Install project development tools (from .mise.toml)
dev-tools-install:
    @printf '%b{{arrow}} Installing project development tools...%b\n' "{{blue}}" "{{nc}}"
    @mise install
    @printf '%b{{checkmark}} Project development tools installed%b\n' "{{green}}" "{{nc}}"

# Update devbase tools
dev-tools-update:
    @printf '%b{{arrow}} Updating mise tools...%b\n' "{{blue}}" "{{nc}}"
    @mise upgrade
    @mise install
    @printf '%b{{checkmark}} Tools updated%b\n' "{{green}}" "{{nc}}"

# Verify installation is complete and working
devbase-install-verify:
    @printf '%b{{arrow}} Verifying dev-base installation...%b\n' "{{blue}}" "{{nc}}"
    @bash verify/verify-install-check.sh