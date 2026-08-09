# What nire-tenacity is made of. Handheld, Jovian/SteamOS.
#
# Sits directly under nireHost/ rather than in a category directory, because
# dirsAsCategory only collects from *sub*directories -- a host definition should
# not become a member of anything.
{ config, ... }:
{
    flake.modules.nixos.tenacityConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/tenacity/: hardware-tenacity, boot-tenacity
        tenacity

        # ── shared ────────────────────────────────────────────────────────────
        # NOT `boot`. That category is WARN-impermanence, whose restore-root
        # service waits on `systemd-cryptsetup@nire-durandal.service` -- hardcoded
        # to the other host. Tenacity's disk has the persist and log subvolumes
        # that only make sense with impermanence, so this is deferred rather than
        # settled; see TENACITY-PLAN.md and the history block in that module.
        hardware        # amdcpu, amdgpu
        nix
        peripherals     # logitech-g600, zsa-moonlander -- both were on the old config
        shell-config
        system

        # `desktop-env` holds kde and jovian, and no host wants both. durandal
        # takes kde directly for the same reason.
        jovian

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal, deliberately. The sibling branch was offered
        # a split that would stop the handheld getting vscode/gimp/libre-office/
        # zoom and chose parity, with the structure left able to split later.
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

    # hostPlatform comes from hardware-tenacity.nix, as mkDefault.
    flake.modules.nixos.tenacityConfiguration.networking.hostName = "nire-tenacity";
    # 25.05, not durandal's 23.11 -- this host was installed later. The sibling
    # branch's tenacity stub said 23.11, which looks like it was copied from
    # durandal; the pre-restructure config that actually ran on this machine
    # (origin/backup-before-flake-parts-happened) says 25.05.
    flake.modules.nixos.tenacityConfiguration.system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
}
