# zram-backed swap for nire-testbed. RAM-backed, not disk-backed, so this
# needs no partition and doesn't touch the real disk layout from
# liveusb-installer.md's step 3 -- hardware-testbed.nix's placeholder
# `swapDevices = [ ]` stays correct either way (zram is a separate
# `/dev/zramN` swap device, not a `swapDevices` entry).
#
# No other host here sets this. tenacity has swap (20G on nvme0n1p6, plus
# zram) but that comes from Jovian's own default profile via the `jovian`
# import, not from anything in this repo -- see WARN-impermanence.nix's
# history note on tenacity's rollback for where that was actually confirmed.
# testbed imports neither Jovian nor any other swap-bearing category, so it
# gets nothing unless something declares it, hence this file.
#
# No hibernation from this: zram can't be a resume target the way a real swap
# partition/file can (there's nothing durable to resume from once RAM is
# gone). If hibernation is ever wanted on this host, that's a separate,
# later decision -- a real swap device sized >= RAM plus boot.resumeDevice --
# not something to bolt onto zram.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # Default algorithm/memoryPercent (zstd, 50%) -- nothing X270-specific
            # about the tuning, just the decision to have it at all.
            zramSwap.enable = lib.mkDefault true;
        };
}
