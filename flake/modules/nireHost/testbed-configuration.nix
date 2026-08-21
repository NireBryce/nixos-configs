# What nire-testbed is made of. ThinkPad X270, workstation/desktop.
#
# This file sits directly under nireHost/ rather than in a category directory,
# because dirsAsCategory only collects from *sub*directories -- a host
# definition should not become a member of anything.
#
# Deliberately does NOT import `impermanence`. Every other host in this repo
# does, and `/root` gets wiped and recreated from a blank snapshot on every one
# of them -- see README.md and CLAUDE.md's safety section before assuming that
# applies here too. It does not: testbed keeps a plain persistent root, and
# invariants.nix was changed alongside this file so its rollback/hibernation/
# persistence checks only apply to hosts that actually have the restore-root
# unit, rather than to every NixOS host unconditionally. See that file's own
# "OPT-IN, SINCE NIRE-TESTBED" comment for why that specific signal.
#
# tailscale-persist.nix was changed the same day for the same reason: with
# environment.persistence declared for every host (see
# nire/system/impermanence/declare-persistence-option.nix), it would otherwise
# have populated an entry for testbed that rescues nothing from a wipe that
# never happens, and tripped impermanence's own "/var/lib/nixos not persisted"
# warning as a side effect. It is gated on the same restore-root signal now.
#
# Deliberately does NOT import the shared `hardware` category either, even
# though durandal and tenacity both do -- that category is AMD-only today
# (amdcpu, amdgpu), and this machine is Intel (Kaby Lake i7-7500U, HD 620).
# Its CPU/GPU handling lives in testbed/hardware/hardware-testbed.nix instead,
# scoped to this host alone, via nixos-hardware's lenovo-thinkpad-x270 module.
# Do not add an `nire/hardware/intel/` sibling to `nire/hardware/amd/` to make
# `hardware` importable here without checking first: durandal and tenacity
# import that category by name, and dirsAsCategory recurses into
# subdirectories, so anything filed under a new `hardware/intel/` would start
# applying to them too.
{ config, ... }:
{
    flake.modules.nixos.testbedConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/testbed/: hardware-testbed, boot-testbed,
        # nixpkgs-hostPlatform-testbed, nixpkgs-stateVersion-testbed
        testbed

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations
        nix
        peripherals
        shell-config
        system

        # Same choice durandal made: a workstation, its own session module
        # rather than the whole `desktop-env` category (which also holds
        # jovian, a handheld-only module this host has no use for).
        # kde-desktop pulls in kde-base itself.
        kde-desktop

        # libvirt/QEMU VMs: libvirt, virt-tools, vm-networking. Kept here on
        # the same grounds as the package parity below -- nothing in it is
        # vendor-specific, and an X270 runs a small guest fine. Drop this line
        # if the machine turns out too thin for it; nothing else depends on it.
        virtualization

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal. Nothing here is Intel/AMD-specific --
        # swept for hidden vendor assumptions before this host was added, and
        # linux-utils/gui-other/etc. are all vendor-neutral package lists.
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

    flake.modules.nixos.testbedConfiguration.networking.hostName = "nire-testbed";
}
