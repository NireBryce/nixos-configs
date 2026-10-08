{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = { config, ... }: {
        # # description = "swap policy toggle - unmanaged zram zswap";

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

        config = lib.mkMerge [
            # Explicit zram for hosts that opt in. mkDefault so Jovian's
            # SteamOS sizing (zstd, 50% of RAM, priority 100) still layers
            # through on a Jovian host, and non-Jovian hosts get the
            # nixpkgs defaults.
            (lib.mkIf (config.customOption.swap.policy == "zram") {
                zramSwap.enable = lib.mkDefault true;
            })

            # zswap fronts whatever `swapDevices` the host declares: a
            # compressed pool in RAM whose least-recently-used pages drain
            # to the backing swap under pressure. Chosen for nire-tenacity
            # with the user (2026-10-04): the machine is mostly a dev box
            # with incidental gaming, so cold pages draining to the
            # encrypted NVMe partition beat zram's never-evicting pool;
            # the huge-page behaviour that favours zram writeback is a
            # gaming-workload phenomenon. Hibernation is no factor either
            # way -- the impermanence hosts boot with `nohibernate` and
            # their swap holds an ephemeral key.
            #
            # The `false` is a plain value on purpose: Jovian reaches
            # zramSwap.enable via mkDefault (jovian.steam.enable ->
            # useSteamOSConfig -> enableZram, modules/steamos/misc.nix in
            # the Jovian flake), and nixpkgs' zswap module asserts
            # `!zramSwap.enable` -- both at once fails eval by design.
            (lib.mkIf (config.customOption.swap.policy == "zswap") {
                zramSwap.enable   = false;
                boot.zswap.enable = true;
            })
        ];
    };
}
