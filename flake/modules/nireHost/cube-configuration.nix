# What nire-cube is made of. GMKtec Nucbox G11, a mini PC -- workstation
# shape, same as durandal, not a handheld (see lego/tenacity-configuration.nix
# for that shape instead).
#
# CPU: AMD Ryzen Embedded R2514, 4c/8t, max boost 3.7GHz, 4MB L3.
# GPU: AMD Radeon integrated graphics (on-die with the R2514).
# Both are plain AMD, same silicon family durandal and lego already run, so
# this host takes the shared `hardware` category (amdcpu, amdgpu) same as
# they do -- unlike testbed, which is Intel and had to skip it.
#
# This file sits directly under nireHost/ rather than in a category directory,
# because dirsAsCategory only collects from *sub*directories -- a host
# definition should not become a member of anything.
#
# Meant as a copy of durandal-configuration.nix's shape -- same category
# imports, same workstation session, WITH impermanence -- adapted for
# hardware that isn't durandal's:
#
#   - b550-suspend-fix.nix is NOT carried over. It clears PCI wakeup on two
#     specific PCI IDs (1022:1483) belonging to durandal's Gigabyte B550M
#     board's Starship/Matisse GPP bridges. The Nucbox G11 is different
#     silicon entirely (embedded SoC, not a socketed B550 board) and almost
#     certainly has different (or no) wakeup bug, so copying a PCI-ID-keyed
#     fix across to hardware it wasn't diagnosed on would be pure
#     superstition. If cube turns out to have its own suspend/wake issue,
#     diagnose it fresh and add a `cube`-specific fix the same way durandal's
#     was added, rather than assuming this one applies.
#
#   - Disk layout comes from disko, not a captured hardware-configuration.nix,
#     because this machine has not been installed yet -- see
#     cube/hardware/disko-cube.nix, which wires in
#     nire/impermanence/_disko/impermanence-luks-btrfs.nix with
#     includeSecureboot = true (matching durandal's own secureboot subvolume)
#     and no swap. The device path in that file is a deliberate placeholder
#     and MUST be checked against the real hardware before this is ever
#     installed -- see that file's own header for why it is not a
#     plausible-looking guess like "/dev/nvme0n1".
#
# WITH impermanence, same as durandal: `/root` gets wiped and recreated from
# a blank snapshot on every boot. Read WARN-impermanence.nix and README.md's
# safety section before touching anything near this.
{ config, ... }:
{
    flake.modules.nixos.cubeConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/cube/: disko-cube, boot-cube, nixpkgs-hostPlatform-cube,
        # nixpkgs-stateVersion-cube -- suffixed for the same reason
        # tenacity's/testbed's/lego's are: a module's name is its filename, and
        # same name in the same class merges rather than erroring.
        cube

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations

        # WARN-impermanence -- wipes /root on boot, see the module.
        #
        # PREREQUISITE: the rollback does
        #   btrfs subvolume snapshot /mnt/root-blank /mnt/root
        # so a `root-blank` subvolume must exist on this machine's btrfs top
        # level. disko-cube.nix's layout creates it -- see that file -- but
        # only once disko has actually been run against the real disk. This
        # host cannot boot successfully before that regardless of what the
        # rest of this config says.
        impermanence

        hardware        # amdcpu, amdgpu -- R2514 + integrated Radeon is AMD
                        # throughout, same shared category durandal and lego
                        # already import.
        nix
        peripherals
        shell-config
        system

        # Same choice durandal made: a workstation, its own session module
        # rather than the whole `desktop-env` category (which also holds
        # jovian, a handheld-only module this host has no use for).
        # kde-desktop pulls in kde-base itself.
        kde-desktop

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal.
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

    flake.modules.nixos.cubeConfiguration.networking.hostName = "nire-cube";
}
