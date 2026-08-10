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
{ config, lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Bound out here, before the module body, on purpose. Inside the body
        # `config` is the *NixOS* config, and `config.flake.modules...` silently
        # stops resolving. Same reasoning as
        # nire/system/home-manager/enable-home-manager.nix.
        kdeBase = config.flake.modules.nixos.kde-base;
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "Plasma 6 as a workstation desktop session, via sddm";
            imports = [ kdeBase ];

            services.displayManager = {
                defaultSession = "plasma";
                sddm = {
                    enable = true;
                    wayland.enable = true;
                };
            };
        };
}
