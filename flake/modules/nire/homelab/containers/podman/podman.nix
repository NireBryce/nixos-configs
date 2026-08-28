{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # Renamed from `virtualization.nix`, which declared
        # `flake.modules.nixos.virtualization`. Everything here is OCI
        # containers -- podman and distrobox -- and never was anything else;
        # `virtualization` now names the VM category (libvirt/QEMU) at
        # nire/virtualization/. Directory was `nire/system/virtualization/`
        # until 2026-08-21 for the same reason.
        #
        # MOVED AGAIN, 2026-08-22: out of `nire/system/containers/` (under
        # `system`, imported whole by every Linux host, no opt-out) into its
        # own category, `nire/containers/` -- the split `virtualization` got
        # 2026-08-21. Unexercised at move time: all four NixOS hosts then
        # (durandal, tenacity, lego, cube) imported `containers` explicitly
        # in place of `system`'s implicit coverage -- no package set changed.
        # Since: durandal dropped it 2026-08-27, lego removed the same day --
        # see wiki/categories/containers.md.
        #
        # RENAMED IN THE SAME MOVE, `containers.nix` -> `podman.nix`: the
        # exact near-miss `virtualization`'s header records, hit for real.
        # The category's `dirsAsCategory.nix` derives its aggregate name from
        # its directory `nire/containers/`, declaring
        # `flake.modules.nixos.containers` -- the same attribute a file still
        # named `containers.nix` would declare from ITS filename; the two
        # would merge invisibly, not conflict, and `just modules` caught it.
        # Named after the technology, like `libvirt.nix` isn't named
        # `virtualization.nix`.
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
            # Both paths needed: /etc/profiles/per-user/elly is an
            # `environment.etc` entry (nixpkgs config/users-groups.nix), a
            # symlink to /etc/static/profiles/per-user/elly, itself a symlink
            # into /nix/store -- mounting only the first gives the container
            # a dangling link.
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

                # NOT autoSubUidGidRange: looks like the obvious thing to
                # write, silently collides with elly below. nixpkgs allocates
                # auto ranges in update-users-groups.pl's allocSubUid, which
                # walks 100000, 165536, ... and skips only ranges *it*
                # already handed out (%subUidsUsed) or on a previous
                # activation (%subUidsPrevUsed, from
                # /var/lib/nixos/auto-subuid-map); it never looks at
                # explicitly-declared subUidRanges, so elly's hardcoded
                # 100000 is invisible: on any fresh install both users get
                # 100000:65536 in /etc/subuid and share a subordinate range.
                # durandal escapes only by accident -- elly was auto-allocated
                # 100000 before the pin below existed, so it is in the map
                # and allocSubUid steps past it. Hence: pin explicitly.
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
                # Pinned rather than auto-allocated so the range cannot move
                # out from under container storage already chowned into it --
                # the fix nixpkgs itself prints when an auto range shifts.
                #
                # No extraGroups: elly is already in `podman` via
                # nireUser/elly/user-settings/elly-user.nix, and extraGroups
                # *concatenates* across modules rather than overriding --
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
