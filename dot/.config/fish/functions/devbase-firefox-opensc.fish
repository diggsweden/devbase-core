# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function devbase-firefox-opensc --description "Configure Firefox to use OpenSC for smart card support"
    set -l opensc_lib "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

    # Check if OpenSC library is installed
    if not test -f "$opensc_lib"
        printf "OpenSC PKCS#11 library not found at: %s\n" $opensc_lib
        printf "\n"
        printf "Install OpenSC with:\n"
        printf "  sudo apt install opensc opensc-pkcs11\n"
        return 1
    end

    # Find Firefox profile directory
    # Firefox 67 introduces one profile per channel [release, nightly, beta]  https://support.mozilla.org/en-US/kb/understanding-depth-profile-installation
    # checking profiles.ini for which profile is set to Default
    set -l firefox_dir ~/.config/mozilla/firefox
    set -l profile_dir $firefox_dir/(grep -m1 '^Default=' $firefox_dir/profiles.ini | string replace 'Default=' '')

    if not test -d "$profile_dir"
        printf "No Firefox profile found.\n"
        printf "\n"
        printf "Please launch Firefox once to create a profile, then run this command again.\n"
        return 1
    end

    set -l pkcs11_file "$profile_dir/pkcs11.txt"

    # Check if already configured
    if test -f "$pkcs11_file"; and grep -q "opensc-pkcs11.so" "$pkcs11_file" 2>/dev/null
        printf "OpenSC is already configured in Firefox.\n"
        printf "\n"
        printf "Profile: %s\n" $profile_dir
        printf "\n"
        printf "To verify, open Firefox and go to:\n"
        printf "  Settings → Privacy & Security → Security Devices\n"
        printf "\n"
        printf "You should see 'OpenSC' listed with your smart card reader.\n"
        return 0
    end

    # Add OpenSC module to pkcs11.txt
    printf "library=%s\n" $opensc_lib >> "$pkcs11_file"
    printf "name=OpenSC\n" >> "$pkcs11_file"

    printf "OpenSC configured for Firefox smart card support.\n"
    printf "\n"
    printf "Profile: %s\n" $profile_dir
    printf "\n"
    printf "Next steps:\n"
    printf "  1. Restart Firefox\n"
    printf "  2. Insert your smart card\n"
    printf "  3. Go to: Settings → Privacy & Security → Security Devices\n"
    printf "  4. You should see 'OpenSC' with your card reader listed\n"
    return 0
end
