# What nire-durandal is made of.
#
# This file sits directly under nireHost/ rather than in a category directory,
# because dirsAsCategory only collects from *sub*directories -- a host definition
# should not become a member of anything.
#
# The list mirrors the `moduleList` the den version carried, translated from den
# aspects to the category aggregates dirsAsCategory now produces.
{ config, ... }:
{
    flake.modules.nixos.durandalConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/durandal/: hardware-durandal, boot-durandal,
        # b550-suspend-fix, nixpkgs-hostPlatform-durandal, nixpkgs-stateVersion-durandal
        # -- suffixed 2026-08-12 so a second nixos host's copies (tenacity's)
        # don't merge into these under the "module name is its filename" rule.
        durandal

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations
        impermanence    # WARN-impermanence -- wipes /root on boot, see the module.
                        # Was `boot` until 2026-08-11; see tenacity-configuration.nix.
        hardware        # amdcpu, amdgpu
        nix
        peripherals
        shell-config
        system

        # `desktop-env` also contains jovian -- a generic handheld module (built-in
        # controllers, occasional SteamOS session), not one host's. Durandal is a
        # workstation and takes its own session module rather than the whole
        # category. kde-desktop pulls in kde-base itself; was plain `kde` before
        # the 2026-08-10 split.
        kde-desktop

        # Deliberately NOT `virtualization` (libvirt/QEMU VMs) or `containers`
        # (podman + distrobox) as of 2026-08-27 -- dropped from this host.
        # Both were imported here since the flake-parts port purely for
        # parity with what the den config carried, on the theory this
        # workstation might use them the way cube's homelab VMs/containers
        # actually did -- but nothing in this repo's history records this
        # host ever actually running a VM or a distrobox container, unlike
        # cube's confirmed usage. Removing them stops `libvirtd`/`podman` on
        # the next `just switch` here. `virtualization` was already
        # host-optional by design (tenacity, the handheld, already
        # declines it) so this doesn't change any documented invariant; the
        # `homelab` category still exists and is unaffected -- `containers`
        # is now cube/tenacity only, and `virtualization` is cube only. See
        # wiki/categories/virtualization.md and wiki/categories/containers.md's
        # "Imported by" sections. If this host ever does need libvirt or
        # podman again, re-add the two lines this comment replaced -- see
        # git history for the exact wording.

        # ── packages ──────────────────────────────────────────────────────────
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

    # den.provides.hostname set this automatically from the aspect name.
    flake.modules.nixos.durandalConfiguration.networking.hostName = "nire-durandal";
}
