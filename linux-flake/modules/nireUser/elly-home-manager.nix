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
# `boot` is listed and is nearly empty: one module, and only because a system
# decision made in that category has a consequence on the home side.
{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports =
    with config.flake.modules.homeManager; [
        # elly-git, elly-session, hm-config (username, homeDirectory, stateVersion)
        elly

        # kde-sleepmode only. The rest of `boot` is nixos-class -- notably
        # WARN-impermanence, which is what makes this necessary: it sets
        # nohibernate, and KDE has to be told to stop asking for hibernation or
        # suspend silently stops working. Both hosts import `boot` on the system
        # side, so both need this.
        boot

        nix             # basic-nix-settings
        shell-config    # bash, blesh, shell-env, zsh
        system          # font, virtualization

        # packages
        development
        editors
        gui-other
        linux-utils
        nix-utils
        shell-apps
        terminals
    ];
}
