# What nire-lego is made of. Legion Go, handheld, Jovian/SteamOS-style
# session -- same shape as nire-tenacity, not durandal's workstation shape.
#
# Sits directly under nireHost/ rather than in a category directory, because
# dirsAsCategory only collects from *sub*directories -- a host definition
# should not become a member of anything.
#
# WITH impermanence, unlike nire-cube, which keeps a plain persistent root.
# That is a real decision either way: `/root` gets wiped and recreated from a
# blank snapshot on every boot here. Read WARN-impermanence.nix and README.md's
# safety section before touching anything near this.
#
# Disk layout comes from disko now, not a captured nixos-generate-config --
# see lego/hardware/disko-lego.nix. It wires in
# nire/impermanence/_disko/impermanence-luks-btrfs.nix at its defaults
# (no secureboot, no swap), which is what makes it structurally identical to
# tenacity's own hand-partitioned layout rather than merely similar. The
# device path in that file is a deliberate placeholder and MUST be checked
# against the real hardware before this is ever installed -- see that file's
# own header for why it is not a plausible-looking guess.
{ config, ... }:
{
    flake.modules.nixos.legoConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/lego/: disko-lego, boot-lego, nixpkgs-hostPlatform-lego,
        # nixpkgs-stateVersion-lego -- suffixed for the same reason tenacity's
        # is: a module's name is its filename, and same name
        # in the same class merges rather than erroring.
        lego

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations

        # WARN-impermanence -- wipes /root on boot, see the module.
        #
        # PREREQUISITE: the rollback does
        #   btrfs subvolume snapshot /mnt/root-blank /mnt/root
        # so a `root-blank` subvolume must exist on this machine's btrfs top
        # level. disko-lego.nix's layout creates it -- see that file -- but
        # only once disko has actually been run against the real disk. This
        # host cannot boot successfully before that regardless of what the
        # rest of this config says.
        impermanence

        hardware        # amdcpu, amdgpu -- Legion Go is AMD (Ryzen Z1
                        # family), so this is the correct shared category.
        nix
        peripherals
        shell-config
        system

        # `desktop-env` also holds kde-base and kde-desktop. jovian is generic
        # to handhelds, not specific to tenacity -- this is the "a second
        # handheld would import it too" that tenacity's own comment already
        # anticipated. Brings services.handheld-daemon and its /etc/hhd
        # persistence along with it; nothing lego-specific needed for that.
        jovian

        # podman + distrobox. Its own category as of 2026-08-22, split out of
        # `system` the same way `virtualization` was -- but not
        # handheld-exclusive the way that one is; all four NixOS hosts import
        # it, same as tenacity's copy of this comment explains.
        containers

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal and tenacity, deliberately, same reasoning
        # as tenacity's own comment on this list.
        development
        editors
        gui-other
        linux-utils
        nix-utils
        shell-apps
        terminals

        # ── user ──────────────────────────────────────────────────────────────
        elly            # elly-user: the account, groups, emergency packages
    ];

    flake.modules.nixos.legoConfiguration.networking.hostName = "nire-lego";
}
