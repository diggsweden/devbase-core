# Completions for devbase-theme command

# Disable file completions for this command
complete -c devbase-theme -f

# Only complete theme names if no theme has been specified yet
# Check that we only have 1 token (the command itself) or we're in the middle of typing the first arg
set -l theme_condition "__fish_is_first_token"

# Theme completions with descriptions - only for first argument
complete -c devbase-theme -n "__fish_is_first_token" -a "everforest-dark" -d "Everforest Dark (default)"
complete -c devbase-theme -n "__fish_is_first_token" -a "everforest-light" -d "Everforest Light"
complete -c devbase-theme -n "__fish_is_first_token" -a "catppuccin-mocha" -d "Catppuccin Mocha"
complete -c devbase-theme -n "__fish_is_first_token" -a "catppuccin-latte" -d "Catppuccin Latte"
complete -c devbase-theme -n "__fish_is_first_token" -a "tokyonight-night" -d "Tokyo Night"
complete -c devbase-theme -n "__fish_is_first_token" -a "tokyonight-day" -d "Tokyo Night Day"
complete -c devbase-theme -n "__fish_is_first_token" -a "gruvbox-dark" -d "Gruvbox Dark"
complete -c devbase-theme -n "__fish_is_first_token" -a "gruvbox-light" -d "Gruvbox Light"
complete -c devbase-theme -n "__fish_is_first_token" -a "nord" -d "Nord"
complete -c devbase-theme -n "__fish_is_first_token" -a "dracula" -d "Dracula"
complete -c devbase-theme -n "__fish_is_first_token" -a "solarized-dark" -d "Solarized Dark"
complete -c devbase-theme -n "__fish_is_first_token" -a "solarized-light" -d "Solarized Light"

# Help option - can be used anytime
complete -c devbase-theme -l help -s h -d "Show help message"
