{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # TODO: these modules should be stored outside of the users folder, so it's clearer when it's imported
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            users.mutableUsers = false;
            users.users = { 
                # groups = {
                #     elly = { };
                # };
                elly = {
                    # group = "elly";
                    # shell = lib.mkDefault pkgs.bash;
                    isNormalUser = true;
                    extraGroups = [ "wheel" "audio" "kvm" ]; # Enable 'sudo', deeper audio access, and
                                                              # /dev/kvm (root:kvm 0660 by default) for
                                                              # hardware-accelerated Android emulation.
                                                              # No `podman` (removed 2026-09-26): the
                                                              # group reaches podman's rootful socket,
                                                              # i.e. passwordless root. Same for
                                                              # `libvirtd` -- see podman.nix, libvirt.nix.
                    hashedPasswordFile = "/persist/passwords/elly";
                    packages  = with pkgs; [ 
                        # Emergency packages if home-manager dies
                        firefox
                        git
                        gh
                        micro
                        tree
                        kdePackages.partitionmanager
                    ];
                };
            };

            # The hash file is made by hand, and all three hosts had it 0644
            # in a 0755 dir -- a login hash every account could read, the
            # thing /etc/shadow's 0640 exists to prevent. Only root reads it
            # (users-groups activation). `d` also tightens an existing dir;
            # `z` adjusts an existing file and creates nothing. Applied at
            # every boot and switch, so a hand-made file can't drift back.
            # Added 2026-09-27.
            systemd.tmpfiles.rules = [
                "d /persist/passwords      0700 root root -"
                "z /persist/passwords/elly 0600 root root -"
            ];
        };

        flake.modules.darwin.${moduleName} = { pkgs, ... }: {
            fonts.packages = with pkgs; [
                nerd-fonts.fira-code
                nerd-fonts.iosevka
                nerd-fonts.jetbrains-mono
            ];
        };
}
