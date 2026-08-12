# Homebrew casks and formulae, for the GUI applications and CLI tools nix
# does not package well on macOS (or that need App Store / notarisation /
# menu-bar integration that a nix-built .app bundle does not get for free).
#
# Ported from macos-old/nire-lysithea-configuration.nix, which had this
# working before the surrounding flake structure (a second, standalone flake
# bridged into this repo by a since-broken symlink) was abandoned. The list
# itself was never the broken part; kept close to verbatim, TODOs and all --
# they are the previous instance of this config's own notes-to-self about
# which casks it no longer remembers the purpose of, and that is honest
# information to keep rather than silently drop.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.darwin.${moduleName} = {
            # # description = "homebrew casks and formulae not covered by nix";
            homebrew = {
                enable = true;

                # Uninstall anything not declared here on activation. This is
                # the aggressive end of nix-darwin's cleanup enum (none / check
                # / uninstall / zap) -- carried over deliberately, since a
                # homebrew install that silently drifts from what is declared
                # defeats the point of declaring it at all.
                onActivation.cleanup = "uninstall";

                taps = [ ];

                brews = [
                    "gifski" # gif creator/converter
                    "magic-wormhole" # easy secure point-to-point file transfer
                ];

                casks = [
                    "audacity" # audio editor
                    "angry-ip-scanner" # does what it says on the tin
                    "app-cleaner" # also does what it says on the tin
                    "balenaetcher" # disk image writer
                    "betterdisplay" # better display settings
                    "bettertouchtool" # touchbar configurator, but also more
                    "bitwarden" # password manager
                    "cd-to" # TODO: dont remember
                    "cleanshot" # screenshot
                    "daisydisk" # disk usage viewer
                    "dash@6" # TODO: dont remember
                    "discord" # why do i have to use discord for everyone
                    "dropshare" # TODO: dont remember
                    "file-juicer" # TODO: dont remember
                    "gimp" # image editor
                    "github" # github desktop
                    "hammerspoon" # automations
                    "iina" # TODO: dont remember
                    "istat-menus" # menu bar stat indicators
                    "jordanbaird-ice" # TODO: dont remember
                    "karabiner-elements" # keyboard rebinder, look into kanata instead
                    "keka" # TODO: dont remember
                    "keyboard-maestro" # TODO: dont remember
                    "kitty" # terminal emulator
                    "latest" # TODO: dont remember
                    "losslesscut" # TODO: dont remember
                    "lulu" # TODO: dont remember
                    "mist" # TODO: dont remember
                    "name-mangler" # bulk rename tool
                    "netnewswire" # rss reader
                    "obsidian" # notes / PKM / wiki-like
                    "openinterminal" # context menu option for opening `finder` location in terminal
                    "orbstack" # VM/OCI manager
                    "pacifist" # TODO: dont remember
                    "raspberry-pi-imager" # lets you set some settings as you flash the pi
                    "raycast" # much better spotlight, clipboard manager
                    "rectangle" # window tiling but not a tiler
                    "rocket" # emoji menu
                    "sloth" # TODO: dont remember
                    "steam" # steam games library
                    "tailscale" # network tunnel
                    "the-unarchiver" # TODO: dont remember
                    "transmit" # TODO: dont remember
                    "unicodechecker" # TODO: dont remember
                    "utm" # another VM thing
                    "visual-studio-code" # VSCode
                    "whisky" # `wine` for mac
                    "xcodes" # version manager for various languages (python?)
                    "xscope" # TODO: dont remember
                    "zoom" # video conferencing
                    "google-chrome" # need for webserial and webBLE apps for devices
                    "autodesk-fusion" # Fusion 180 (personal featureless edition)
                    "fantastical" # Calendar Software
                    "moonlight" # moonlight game streaming (sunshine on durandal)
                    "mullvadvpn" # mullvad vpn
                    "insta360-studio" # 360 video editor
                    "espanso" # global text expansions -- see the homeManager
                              # espanso module too; check for a real conflict
                              # before running both on the same machine
                    "firefox" # TODO: this might break FF it used to be system managed
                    "obs"
                ];
            };
        };
}
