# dirs-as-categories: the module is named after this file; its categories are the folders above it
# Durandal's session: the workstation half of what used to be kde.nix.
#
# Was `kde.nix`, so the module this declares was `flake.modules.nixos.kde` until
# 2026-08-10 -- filenames are attribute names here, and the old one is no longer
# greppable. durandal-configuration.nix was the only thing that named it.
#
# Everything shared with the handheld moved to kde-base.nix, which this imports.
# What is left is specific to a machine that boots to a desktop rather than to a
# Steam session: tenacity's display manager and default session both come from
# Jovian instead. See kde-base.nix's history block.
{
    # kde-base by name: dirs-as-categories imports it into this module. Was
    # `kdeBase = config.flake.modules.nixos.kde-base` in a `let`, bound outside
    # the module body because inside it `config` is the NixOS one (same
    # reasoning as general-config/system/home-manager/enable-home-manager.nix).
    includes.nixos = [ "kde-base" ];

    nixos = {
        # Plasma 6 as a workstation desktop session, via sddm; kde-base comes
        # from `includes` above.

        services.displayManager = {
            defaultSession = "plasma";
            sddm = {
                enable = true;
                wayland.enable = true;
            };
        };
    };
}
