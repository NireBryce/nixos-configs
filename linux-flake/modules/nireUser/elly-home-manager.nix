# elly's whole Home Manager config, as one module.
#
# The home-side counterpart to nireHost/durandal-configuration.nix, and it sits
# directly under nireUser/ for the same reason: dirsAsCategory only collects from
# *sub*directories, so a file here does not become a member of anything.
#
# Only the categories that actually contain homeManager modules are listed. Every
# category is declared for all three classes, so `boot`, `hardware`, `peripherals`
# and `durandal` also exist here -- as empty aggregates. Importing them would be
# harmless but would suggest content that is not there.
{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports =
    with config.flake.modules.homeManager; [
        # elly-git, elly-session, hm-config (username, homeDirectory, stateVersion)
        elly

        nix             # basic-nix-settings
        shell-config    # bash, blesh, fish, shell-env, zsh
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
