# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = {
        # summary: declares customOption.swap.policy; swap-policy.nix reads it

        options.customOption.swap.policy = lib.mkOption {
            # `customOption.*` is this deployment's namespace for local
            # policy knobs, chosen 2026-10-04: person-neutral, and namespaced
            # deeply enough that neither nixpkgs (module-domain namespaces
            # only) nor any input module plausibly grows the same name.
            # Future local options belong here, not in new top-level names.
            type        = lib.types.enum [ "unmanaged" "zram" "zswap" ];
            default     = "unmanaged";
            description = ''
                How the host manages swap. `unmanaged` (the default)
                configures nothing, so a host gets whatever its imported
                modules set -- on the Jovian host that is SteamOS-style
                zram arriving through Jovian defaults. `zram` turns zram
                on explicitly. `zswap` turns zram off and puts zswap in
                front of the host's `swapDevices`; the NixOS module
                system refuses to evaluate both at once (double
                compression).
            '';
        };
    };
}
