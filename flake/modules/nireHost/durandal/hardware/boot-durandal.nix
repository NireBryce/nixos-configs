# renamed from `boot.nix`, which declared `flake.modules.nixos.boot` and so
# merged with the `nire/boot/` category of the same name
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
            sbctl # secure boot ctl
            ];
            boot.loader = {
                systemd-boot.enable = lib.mkDefault true;
                efi.canTouchEfiVariables = lib.mkDefault true;
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-08 — why this file is not called `boot.nix`
#
# It was, and a module's filename becomes its attribute name, so it declared
# `flake.modules.nixos.boot`. dirsAsCategory gives the `nire/boot/` category
# that same name. Same-named modules MERGE rather than conflicting, so the two
# silently became one module, and both directions of that were wrong:
#
#   - importing the `boot` category also applied durandal's systemd-boot and
#     sbctl config, below
#   - importing durandal's bootloader also applied WARN-impermanence, which
#     deletes the /root btrfs subvolume in initrd on every boot
#
# Nothing was broken on this host, because durandal wants both — which is
# exactly why it went unnoticed. A second host importing `boot` for its
# impermanence setup would have inherited another machine's bootloader, and one
# importing this file would have inherited a root wipe.
#
# Renamed so the two names stay distinct. `just modules` now fails on any
# module whose filename matches a category name, which is the general form.
