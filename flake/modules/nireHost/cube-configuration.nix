# What nire-cube is made of. GMKtec Nucbox G11, a mini PC -- workstation
# shape, same as durandal, not a handheld (see tenacity-configuration.nix
# for that shape instead).
#
# CPU: AMD Ryzen Embedded R2514, 4c/8t, max boost 3.7GHz, 4MB L3.
# GPU: AMD Radeon integrated graphics (on-die with the R2514).
# Both are plain AMD, same silicon family durandal already runs, so
# this host takes the shared `hardware` category (amdcpu, amdgpu) same as
# it does.
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
# persistent root, not the `/root`-wipe durandal and tenacity have.
# `impermanence` is deliberately NOT in this file's imports below.
# invariants.nix's rollback, hibernation, and persistence checks are gated on
# the restore-root initrd unit existing (see its "hosts without impermanence
# opt out" header) so they don't apply here. WARN-password-required.nix would
# otherwise fire its warning on this host for the same reason --
# elly-user.nix's hashedPasswordFile still points at /persist/passwords/elly
# unconditionally, and nothing in this repo creates that file -- but it's
# specifically excluded by hostname there: the hash was created by hand on
# the real machine before this was ever switched to, and cube's plain
# persistent root never wipes it back out, so the reminder has nothing left
# to remind about. Read WARN-impermanence.nix and README.md's safety section
# before assuming any of that has changed for cube specifically.
{ config, ... }:
{
    flake.modules.nixos.cubeConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/cube/: hardware-cube, boot-cube, nixpkgs-hostPlatform-cube,
        # nixpkgs-stateVersion-cube -- suffixed for the same reason
        # tenacity's are: a module's name is its filename, and
        # same name in the same class merges rather than erroring.
        cube

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations

        # Deliberately NOT `impermanence` -- see the header above. This host
        # keeps a plain persistent root, not the `/root` wipe
        # durandal/tenacity have.

        hardware        # amdcpu, amdgpu -- R2514 + integrated Radeon is AMD
                        # throughout, same shared category durandal
                        # already imports.
        nix
        peripherals
        shell-config
        system

        # Same choice durandal made: a workstation, its own session module
        # rather than the whole `desktop-env` category (which also holds
        # jovian, a handheld-only module this host has no use for).
        # kde-desktop pulls in kde-base itself.
        kde-desktop

        # Every self-hosted/homelab service this host runs, as one aggregate
        # -- added 2026-08-27, folding what used to be seven separate
        # imports here (virtualization, containers, monitoring, git-forge,
        # shortlinks, reverse-proxy, landing) into `nire/homelab/`. Each of
        # those is still its own category nested under it
        # (`nire/homelab/<name>/`, each keeping its own `dirsAsCategory.nix`)
        # and still individually importable by name -- tenacity still pulls
        # `containers` directly, unaffected by this move (durandal dropped
        # both `virtualization` and `containers` 2026-08-27, the same day
        # this move landed; cube's own copies come through `homelab` now),
        # per the same coarse-and-fine nesting `nire/hardware`/
        # `nire/hardware/amd` already established (see
        # flake/doc/dirsAsCategory.md). All of it was cube-only before this
        # move and stays cube-only now -- nothing here belongs on the
        # handhelds, which is the reason each got its own category in the
        # first place rather than living in `system`.
        #
        # Individual per-service mechanism notes (Tailscale-only reachability,
        # the category/module name-collision reasons `git-forge` isn't
        # `forgejo`, `shortlinks` isn't `golink`, `reverse-proxy` isn't
        # `caddy`, `landing` isn't `glance`/`dashboard`, and the `landing` /
        # `reverse-proxy` pairing) live on each service's own module header
        # and in `wiki/categories/`, not repeated here now that they share
        # one import line.
        homelab

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
