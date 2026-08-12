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
# included -- see enable-home-manager-darwin.nix. Two of the categories below
# (`linux-utils`, `impermanence`) contain content that only makes sense on
# Linux. The fix for that is NOT here: `imports` cannot depend on `pkgs` under
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
# So: import everything unconditionally, same as always, and guard each
# Linux-only *module* internally with `lib.mkIf (!pkgs.stdenv.isDarwin) { ... }`,
# the same pattern vicinae.nix already uses for the identical reason. See the
# individual files under linux-utils/ and kde-sleepmode.nix.
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
        linux-utils     # each module here excludes darwin itself; see the
                        # directory
        nix-utils
        shell-apps
        terminals
    ];
}
