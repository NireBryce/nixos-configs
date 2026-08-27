# The persistence half of libvirt.nix.
#
# /var/lib/libvirt/secrets/secrets-encryption-key encrypts libvirt's own
# stored secrets (e.g. an encrypted storage pool's passphrase). Everything
# else libvirtd drops under /var/lib/libvirt on first run -- the stock
# nwfilter XML, qemu/networks/default.xml -- is libvirtd recreating its own
# defaults and not worth persisting; this key is different, because losing it
# doesn't recreate a default, it orphans whatever it was encrypting. Found
# 2026-08-22 via root-drift.sh flagging it as real (non-cosmetic) drift,
# alongside NetworkManager's secret_key -- see networkmanager-persist.nix.
#
# Filed beside libvirt.nix rather than in the impermanence category, same
# reasoning as tailscale-persist.nix: persistence for state that only matters
# to one thing lives next to what generates it, and being a sibling means the
# same category (`virtualization`) collects it -- reaching exactly the hosts
# libvirt.nix reaches, not more.
#
# GUARDED the same way and for the same reason as tailscale-persist.nix:
# `virtualization` is imported by nire-cube as well as nire-durandal, and cube
# has no impermanence (CLAUDE.md, Safety). An unguarded entry there would be a
# same-filesystem bind mount rescuing state from a wipe that never happens,
# plus a spurious "Neither /var/lib/nixos nor any of its parents are
# persisted" warning the moment ANY environment.persistence entry exists
# without it alongside.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, lib, ... }:
            lib.mkIf (config.boot.initrd.systemd.services ? restore-root) {
                environment.persistence."/persist".files = [ "/var/lib/libvirt/secrets/secrets-encryption-key" ];
            };
}
