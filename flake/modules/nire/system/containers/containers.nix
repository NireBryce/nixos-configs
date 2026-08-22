{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # renamed from `virtualization.nix`, which declared
        # `flake.modules.nixos.virtualization`. Everything here is OCI containers
        # -- podman and distrobox -- and never was anything else; the word
        # `virtualization` now names the VM category at nire/virtualization/,
        # which is libvirt/QEMU and is not imported by every host the way this
        # is. The directory was `nire/system/virtualization/` until 2026-08-21
        # for the same reason the file was.
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "podman, distrobox, and the subuid pinning they need";
            environment.systemPackages = with pkgs; [
                distrobox
                distrobox-tui
                distroshelf
                boxbuddy
                host-spawn
                podman-compose
            ];
            # expose profile to distrobox containers
            #
            # Both paths are needed, not one. /etc/profiles/per-user/elly is an
            # `environment.etc` entry (nixpkgs config/users-groups.nix), so on the
            # host it is a symlink to /etc/static/profiles/per-user/elly, which is
            # itself the symlink into /nix/store. Mounting only the first gives the
            # container a dangling link.
            environment.etc."distrobox/distrobox.conf".text = ''
                container_additional_volumes="/nix/store:/nix/store:ro /etc/profiles/per-user:/etc/profiles/per-user:ro /etc/static/profiles/per-user:/etc/static/profiles/per-user:ro"
            '';
            virtualisation.podman = {
                enable = true;
                dockerCompat = true;
                defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
            };

            virtualisation.oci-containers.backend = "podman";

            users.groups.container = { };
            users.users.container = {
                isNormalUser = true;
                group        = "container";
                home         = "/var/lib/container";
                linger       = true;
                createHome   = true;

                # NOT autoSubUidGidRange. That looks like the obvious thing to write
                # and it silently collides with elly below. nixpkgs allocates auto
                # ranges in update-users-groups.pl's allocSubUid, which walks
                # 100000, 165536, ... and skips only ranges *it* has already handed
                # out (%subUidsUsed) or handed out on a previous activation
                # (%subUidsPrevUsed, from /var/lib/nixos/auto-subuid-map). It never
                # looks at explicitly-declared subUidRanges. So elly's hardcoded
                # 100000 is invisible to it, and on a machine with no prior map file
                # -- i.e. any fresh install, nire-lego included --
                # both users get 100000:65536 in /etc/subuid and share a subordinate
                # range. durandal only escapes this by accident: elly was auto-
                # allocated 100000 before the pin below existed, so it is in the map
                # and allocSubUid steps past it.
                #
                # Hence: pin explicitly, in the block after elly's.
                subUidRanges = [
                {
                    startUid = 165536;
                    count    = 65536;
                }
                ];
                subGidRanges = [
                {
                    startGid = 165536;
                    count    = 65536;
                }
                ];
            };

            users.users.elly = {
                # credit: https://github.com/NixOS/nixpkgs/issues/389088#issuecomment-3379482882
                #
                # Pinned rather than auto-allocated so the range cannot move out from
                # under container storage that is already chowned into it. This is
                # the fix nixpkgs itself prints when an auto range shifts.
                #
                # No extraGroups here. elly is already in `podman` via
                # nireUser/elly/user-settings/elly-user.nix, and extraGroups is a
                # list that *concatenates* across modules rather than overriding --
                # naming it in both places put "podman" in the list twice.
                subUidRanges = [
                {
                    startUid = 100000;
                    count    = 65536;
                }
                ];
                subGidRanges = [
                {
                    startGid = 100000;
                    count    = 65536;
                }
                ];
            };

            # # vscode devcontainers https://wiki.nixos.org/wiki/Podman
            # # Global `/etc/containers/registries.conf`
            # environment.etc."containers/registries.conf".text = ''
            #     [registries.search]
            #     registries = ['docker.io']
            # '';
        };

    # flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
    #         User-scoped `~/.config/containers/registries`
    #         https://wiki.nixos.org/wiki/Podman#DevContainers
    #         xdg.configFile."containers/registries.conf".text = ''
    #           [registries.search]
    #           registries = ['docker.io']
    #         '';
    #     };
}
