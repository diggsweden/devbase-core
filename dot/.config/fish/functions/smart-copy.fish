function smart-copy --description "Auto-detect and use appropriate clipboard utility"
    if type -q clip.exe
        clip.exe
    else if test "$XDG_SESSION_TYPE" = "wayland"; and type -q wl-copy
        wl-copy
    else if type -q xclip
        xclip -selection clipboard
    else if type -q xsel
        xsel --clipboard --input
    else
        printf "No clipboard utility found\n" >&2
        return 1
    end
end