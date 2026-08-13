# elly's whole Home Manager config, as one module.
#
# The home-side counterpart to nireHost/durandal-configuration.nix, and it sits
# directly under nireUser/ for the same reason: dirsAsCategory only collects from
# *sub*directories, so a file here does not become a member of anything.
#
# Only the categories that actually contain homeManager modules are listed. Every
# category is declared for all three classes, so `hardware`, `peripherals`,
# `desktop-env` and `durandal` also exist here -- as empty aggregates. Importing
# them would be harmless but would suggest content that is not there.
#
# `impermanence` is listed and is nearly empty: one module, and only because a
# system decision made in that category has a consequence on the home side.
# Was `boot` until 2026-08-11.
#
# This whole bundle is reused as-is by every host, nire-lysithea (darwin)
# included -- see enable-home-manager-darwin.nix. Some of what it carries only
# makes sense on Linux. The fix for that is NOT here: `imports` cannot depend on `pkgs` under
# useGlobalPkgs without a genuine infinite recursion -- `pkgs` for a
# useGlobalPkgs home-manager module is itself threaded in through
# `_module.args`, which is not resolved until after `imports` is, so
# conditioning `imports` on `pkgs.stdenv.isLinux` is a real cycle, not just
# something nix happens to disallow. Confirmed by trying it: durandal and
# tenacity both failed to evaluate with "infinite recursion encountered",
# naming this exact shape in nixpkgs' own error text -- "if you are trying to
# achieve a conditional import behavior dependent on config, consider
# importing unconditionally, and using mkEnableOption and mkIf to control its
# effect."
#
# So: import everything unconditionally, same as always, and deal with darwin
# per *module* rather than per import. Two mechanisms, and they answer
# different questions -- see CLAUDE.md, "Platform support is derived; Homebrew
# overlap is not":
#
#   can't build there   nothing to do. nire/system/home-manager/
#                       drop-unsupported-packages.nix filters home.packages by
#                       meta.platforms on darwin and warns about what it took.
#
#   won't work there    an explicit `lib.mkIf (!pkgs.stdenv.isDarwin) { ... }`
#                       in the module, because the package builds and the
#                       objection is behavioural. kde-sleepmode.nix and
#                       vicinae.nix are the two, both option-shaped: the HM
#                       module asserts before any package list exists, so the
#                       filter cannot reach them.
{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports =
    with config.flake.modules.homeManager; [
        # elly-git, elly-session, hm-config (username, homeDirectory, stateVersion)
        elly

        # kde-sleepmode only. The rest of `impermanence` is nixos-class --
        # notably WARN-impermanence, which is what makes this necessary: it
        # sets nohibernate, and KDE has to be told to stop asking for
        # hibernation or suspend silently stops working. Both Linux hosts
        # import `impermanence` on the system side, so both need this;
        # kde-sleepmode.nix itself is what excludes darwin.
        impermanence

        nix             # basic-nix-settings
        shell-config    # bash, blesh, shell-env, zsh
        system          # font, virtualization

        # packages
        development
        editors
        gui-other
        linux-utils     # the name stopped being true on 2026-08-12: the
                        # per-module darwin guards came off and all twelve
                        # install on lysithea too. They all build there, and
                        # only pciutils and usbutils are inert on macOS -- the
                        # rest (lsof, nmap, mtr, socat, dnsutils, whois,
                        # iperf3, ldns, iftop, ipcalc) are the same tools they
                        # are on Linux. Renaming the directory would rename
                        # this attribute and every reference to it, so it is a
                        # deliberate change rather than a tidy-up.
        nix-utils
        shell-apps
        terminals
    ];
}
