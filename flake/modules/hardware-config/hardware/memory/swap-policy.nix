# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = { config, ... }: {
        # summary: swap policy toggle - unmanaged zram zswap

        # The option itself is declared in swap-policy-options.nix.

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
