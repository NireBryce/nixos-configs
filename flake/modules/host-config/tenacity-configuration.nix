# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: What nire-tenacity is made of. Handheld, Jovian/SteamOS.
#
# Sits directly under host-config/ rather than in a category directory, because
# a file directly in an area belongs to no category -- a host definition should
# not become a member of anything.
{
    enables.homeManager = [ "tenacity" ];

    includes.nixos = [
        # ── this machine ──────────────────────────────────────────────────────
        # host-config/tenacity/: hardware-tenacity, boot-tenacity,
        # touchscreen-wakeup-tenacity, iommu-tenacity,
        # nixpkgs-hostPlatform-tenacity, nixpkgs-stateVersion-tenacity -- suffixed
        # because a module's name is its filename: two nixos hosts both
        # declaring a bare nixpkgs-hostPlatform.nix would merge into one module
        # instead of erroring. Caught by `just modules` the first time these
        # were added unsuffixed; durandal's copies got the same suffix treatment
        # right after, for the same reason.
        "tenacity"

        # ── shared ────────────────────────────────────────────────────────────
        "boot"          # common boot options: boot-generations, boot-editor

        # WARN-impermanence -- wipes /root on boot, see the module. Was the
        # `boot` category until 2026-08-11; renamed because `boot` had come to
        # mean only this, and read as though it covered bootloader concerns it
        # never did. This host ran it before the restructure too, and its disk
        # still has the persist and log subvolumes that only make sense with it.
        #
        # PREREQUISITE: the rollback does
        #   btrfs subvolume snapshot /mnt/root-blank /mnt/root
        # so a `root-blank` subvolume must exist on this machine's btrfs top
        # level. It should, from when this host last ran impermanence, but the
        # first boot after switching is where you would find out otherwise.
        "impermanence"

        "hardware"      # amdcpu, amdgpu
        "nix"
        # no `peripherals` (logitech-g600, zsa-moonlander): neither device is
        # used on the handheld -- dropped 2026-10-15, the per-host question of #440.
        "shell-config"
        "system"

        # `desktop-env` holds kde-base, kde-desktop and jovian. The shared Plasma
        # 6 desktop is kde-base, which both jovian and kde-desktop import
        # themselves -- so each host takes only its own session module and the
        # category is still never imported whole. jovian is generic to handhelds,
        # not specific to this host; a second handheld would import it too.
        #
        # kde-desktop is the half this host must NOT have: sddm, and
        # defaultSession = "plasma". jovian sets both itself (SDDM on Wayland,
        # plasma default, no autologin; jovian.steam.autoStart is off).
        "jovian"

        # Deliberately NOT `containers` (podman + distrobox) as of
        # 2026-09-26. It enables podman's rootful socket, and the `podman`
        # group that can reach it is root-equivalent with no password
        # (nixpkgs' own dockerSocket docs say so) -- so any process
        # running as the user could read swap, or anything else. Same
        # decision durandal made 2026-08-27; `containers` is now cube only.
        # Was imported here since 2026-08-22, when it split out of `system`.

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal, deliberately. The sibling branch was offered
        # a split that would stop the handheld getting vscode/gimp/libre-office/
        # zoom and chose parity, with the structure left able to split later.
        "development"
        "editors"
        "gui-other"
        "linux-utils"
        "nix-utils"
        "shell-apps"
        "terminals"

        # ── user ──────────────────────────────────────────────────────────────
        "elly"          # elly-user: the account, groups, emergency packages
    ];

    nixos = { enabled, ... }: {
        # hostPlatform comes from hardware-tenacity.nix AND
        # tenacity/configuration/nixpkgs-hostPlatform-tenacity.nix, both mkDefault with
        # the same value -- same redundant-but-harmless shape durandal has between
        # hardware-durandal.nix and nixpkgs-hostPlatform-durandal.nix. stateVersion
        # moved to tenacity/configuration/nixpkgs-stateVersion-tenacity.nix.
        networking.hostName = "nire-tenacity";

        # enabled.homeManager.tenacity is the homeManager side of this host's own
        # `tenacity` category (declared above in `enables`; every category exists
        # in every class) -- currently just
        # tenacity/configuration/plasma-tenacity.nix. Appended onto
        # home-manager.users.elly.imports (set to elly-home-manager by
        # enable-home-manager.nix, part of the `system` import above) rather than
        # replacing it: HM's users.<name> option merges across NixOS modules the
        # same way home.file/home.sessionPath do (CLAUDE.md, "Editing Home
        # Manager shell/dotfile modules"), so this reaches only nire-tenacity's
        # home-manager user without touching elly-home-manager itself -- durandal,
        # lysithea and cube never see plasma-manager's HM module load.
        home-manager.users.elly.imports = [ enabled.homeManager.tenacity ];
    };
}
