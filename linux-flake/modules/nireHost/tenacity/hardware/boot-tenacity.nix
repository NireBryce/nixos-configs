{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # The old config force-disabled limine here, with the note "hack,
            # replace after switching tinylaptop to limine". Nothing on this
            # branch enables limine and NixOS defaults it off, so the mkForce is
            # dropped rather than carried over.
            #
            # No efi.canTouchEfiVariables, matching what this host actually ran
            # with. durandal sets it; tenacity never did.
            boot.loader.systemd-boot.enable = lib.mkDefault true;
        };
}
