# What nire-cube is made of. GMKtec Nucbox G11, a mini PC -- workstation
# shape, same as durandal, not a handheld (see lego/tenacity-configuration.nix
# for that shape instead).
#
# CPU: AMD Ryzen Embedded R2514, 4c/8t, max boost 3.7GHz, 4MB L3.
# GPU: AMD Radeon integrated graphics (on-die with the R2514).
# Both are plain AMD, same silicon family durandal and lego already run, so
# this host takes the shared `hardware` category (amdcpu, amdgpu) same as
# they do.
#
# This file sits directly under nireHost/ rather than in a category directory,
# because dirsAsCategory only collects from *sub*directories -- a host
# definition should not become a member of anything.
#
# Meant as a copy of durandal-configuration.nix's shape -- same category
# imports, same workstation session -- adapted for hardware that isn't
# durandal's:
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
#   - Disk layout comes from a captured hardware-configuration, not disko.
#     cube/hardware/disko-cube.nix used to wire in
#     nire/impermanence/_disko/impermanence-luks-btrfs.nix against a
#     deliberate placeholder device, from when this host had not been
#     installed yet. It was installed by hand instead, off the stock NixOS
#     live ISO -- plain persistent btrfs root, no LUKS -- so that file was
#     deleted and replaced with cube/hardware/hardware-cube.nix, a real
#     nixos-generate-config capture. See that file's own header and history
#     note for the full story.
#
# WITHOUT impermanence, unlike durandal: this host was installed with a plain
# persistent root, not the `/root`-wipe durandal, tenacity, and lego have.
# `impermanence` is deliberately NOT in this file's imports below.
# invariants.nix's rollback, hibernation, and persistence checks are gated on
# the restore-root initrd unit existing (see its "hosts without impermanence
# opt out" header) so they don't apply here. WARN-password-required.nix fires
# its warning
# on this host for the same reason -- elly-user.nix's hashedPasswordFile still
# points at /persist/passwords/elly unconditionally, and nothing in this repo
# creates that file; it was created by hand on the real machine before this
# was ever switched to. Read WARN-impermanence.nix and README.md's safety
# section before assuming any of that has changed for cube specifically.
{ config, ... }:
{
    flake.modules.nixos.cubeConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/cube/: hardware-cube, boot-cube, nixpkgs-hostPlatform-cube,
        # nixpkgs-stateVersion-cube -- suffixed for the same reason
        # tenacity's/lego's are: a module's name is its filename, and
        # same name in the same class merges rather than erroring.
        cube

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations

        # Deliberately NOT `impermanence` -- see the header above. This host
        # keeps a plain persistent root, not the `/root` wipe
        # durandal/tenacity/lego have.

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

        # libvirt/QEMU VMs: libvirt, virt-tools, vm-networking. Same choice
        # durandal made. Not imported by tenacity or lego, which is the whole
        # reason this is a category of its own instead of part of `system`.
        virtualization

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
