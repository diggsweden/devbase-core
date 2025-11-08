# Completions for devbase-font command

# Disable file completions for this command
complete -c devbase-font -f

# Font completions with descriptions - only for first argument
complete -c devbase-font -n "__fish_is_first_token" -a "jetbrains-mono" -d "JetBrains Mono - Excellent readability"
complete -c devbase-font -n "__fish_is_first_token" -a "firacode" -d "Fira Code - Extensive ligatures"
complete -c devbase-font -n "__fish_is_first_token" -a "cascadia-code" -d "Cascadia Code - Microsoft font"
complete -c devbase-font -n "__fish_is_first_token" -a "monaspace" -d "Monaspace - Superfamily (default)"
