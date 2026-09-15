# Homebrew casks and formulae, for the GUI applications and CLI tools nix
# does not package well on Aarch64 (or that need App Store / notarisation /
# menu-bar integration that a nix-built .app bundle does not get for free).
#
# Ported from macos-old/nire-lysithea-configuration.nix, which had this
# working before the surrounding flake structure was abandoned; the list
# was never the broken part, so it is kept close to verbatim, TODOs and all
# -- they are the old config's own notes-to-self about which casks it no
# longer remembers the purpose of, and that is honest information to keep.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.darwin.${moduleName} = {
            # homebrew casks and formulae not covered by nix
            homebrew = {
                enable = true;

                # Uninstall anything not declared here on activation, since a
                # homebrew install that silently drifts from what is declared
                # defeats the point of declaring it at all.
                #
                # nix-darwin turns this into `brew bundle --force-cleanup`
                # (modules/homebrew.nix:196), a switch Homebrew added in 6.0.0.
                # This option spent 2026-08-12..24 worked around as
                # `cleanup = "none"` + `extraFlags = [ "--cleanup" ]` on
                # Homebrew 5.x; that workaround is 5.x-only and breaks on 6.x.
                # Read the history block at the bottom before reaching for it
                # again -- neither spelling works on both generations.
                onActivation.cleanup = "uninstall";

                taps = [ ];

                brews = [
                    "gifski" # gif creator/converter
                    "magic-wormhole" # easy secure point-to-point file transfer
                    "opencode" # LLM coding agent CLI
                    "python@3.13" # kept explicitly: `cleanup = "uninstall"`
                                  # removes anything undeclared; this was
                                  # installed by hand, not as a dep
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
                    "tailscale-app" # network tunnel -- renamed from `tailscale` by homebrew
                    "the-unarchiver" # TODO: dont remember
                    "transmit" # TODO: dont remember
                    "unicodechecker" # TODO: dont remember
                    "utm" # another VM thing
                    "visual-studio-code" # VSCode
                    "whisky" # `wine` for mac
                    "xcodes-app" # renamed from `xcodes` by homebrew; version manager for various languages (python?)
                    "xscope" # TODO: dont remember
                    "zoom" # video conferencing
                    "google-chrome" # need for webserial and webBLE apps for devices
                    "autodesk-fusion" # Fusion 180 (personal featureless edition)
                    "fantastical" # Calendar Software
                    "moonlight" # moonlight game streaming (sunshine on durandal)
                    "mullvad-vpn" # mullvad vpn -- renamed from `mullvadvpn` by homebrew
                    "insta360-studio" # 360 video editor
                    "espanso" # global text expansions -- see the homeManager
                              # espanso module too; check for a real conflict
                              # before running both at once
                    "firefox" # TODO: this might break FF it used to be system managed
                    "obs"
                    "zcode" # AI-assisted development environment
                ];
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# Round trip: `onActivation.cleanup = "uninstall"` -> workaround 2026-08-12,
# reverted 2026-08-24 (both spellings above). The obvious reading of the
# reverted diff -- "someone put back a flag that was removed upstream" -- is
# backwards.
#
# On Homebrew 5.1.6 nix-darwin's translated `--force-cleanup` (see above) did
# not exist, and activation died with `Error: invalid option --force-cleanup`.
# Its arg parser declared `--cleanup` and `--force` separately, and `brew
# bundle --help` called bare `--cleanup` "same as running cleanup --force", so
# passing `--cleanup` by hand through `extraFlags`, the option set to "none" so
# nix-darwin would not also emit the dead flag, was the same behaviour by a
# working spelling.
#
# Homebrew 6 undid both halves: `--force-cleanup` is a real switch again
# (`bundle/subcommand/install.rb:49`, "Perform cleanup after installing
# dependencies without asking"), and bare `--cleanup` is deprecated and no
# longer implies force -- without `--force`/`--force-cleanup`/`$HOMEBREW_ASK` it
# is a DRY RUN, prints `Would uninstall …` and `Run brew bundle cleanup --force
# to make these changes`, and exits 1. The workaround stopped cleaning anything
# up and failed every `just switch` (Homebrew 6.0.19).
#
# The failure hides by shape: nh reports only the subprocess's stderr and the
# dry run goes to stdout, so activation looked like a wall of harmless
# `Warning: <cask> was renamed to …` lines and no error at all. The renames
# were unrelated to the exit code (fixed in the same change: tailscale ->
# tailscale-app, xcodes -> xcodes-app, mullvadvpn -> mullvad-vpn). Diagnosed by
# hand-running the activation script's `brew bundle` line: stderr matched the
# failure byte for byte; the answer was on stdout.
#
# The revert made cleanup actually uninstall. `brew leaves` and the dry run's
# own `Would uninstall` list were checked first: cask `zcode` and formulae
# `opencode` and `python@3.13` were installed by hand and wanted, so they were
# added to the lists above in the same change.
# Everything else the dry run named (`node`, `ripgrep`, `pcre2`, `icu4c@78`,
# `libuv`, ...) was a dependency of those and comes back on demand.
