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
# It was, and its filename made it declare `flake.modules.nixos.boot` — the
# same name dirsAsCategory gives the `nire/boot/` category. Same-named
# modules MERGE rather than conflict, so the two silently became one, and
# both directions were wrong:
#
#   - importing the `boot` category also applied durandal's systemd-boot and
#     sbctl config
#   - importing durandal's bootloader also applied WARN-impermanence, which
#     deletes the /root btrfs subvolume in initrd on every boot
#
# Durandal wants both, which is why it went unnoticed — another host
# importing `boot` for its impermanence setup would have inherited another
# machine's bootloader, and one importing this file a root wipe. Renamed so
# the two names stay distinct; `just modules` now fails on any module whose
# filename matches a category name, the general form.
