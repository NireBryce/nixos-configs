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
        # WARN-impermanence -- wipes /root on boot, see the module. This host ran
        # it before the restructure too, and its disk still has the persist and
        # log subvolumes that only make sense with it.
        #
        # PREREQUISITE: the rollback does
        #   btrfs subvolume snapshot /mnt/root-blank /mnt/root
        # so a `root-blank` subvolume must exist on this machine's btrfs top
        # level. It should, from when this host last ran impermanence, but the
        # first boot after switching is where you would find out otherwise.
        boot

        hardware        # amdcpu, amdgpu
        nix
        peripherals     # logitech-g600, zsa-moonlander -- both were on the old config
        shell-config
        system

        # `desktop-env` holds kde and jovian and no host wants both, so each takes
        # the one it wants directly. jovian is generic to handhelds -- machines
        # with built-in controllers that occasionally launch a SteamOS session --
        # not specific to this host; a second handheld would import it too.
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
