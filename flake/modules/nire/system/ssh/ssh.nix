{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = {
            services.openssh = {
                enable = true;
                allowSFTP = false; # Don't set this if you need sftp
                settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
                };
                extraConfig = ''
                AllowTcpForwarding          yes
                X11Forwarding               no
                AllowAgentForwarding        no
                AllowStreamLocalForwarding  no
                AuthenticationMethods       publickey
                '';
            };
            users.users.elly = {
                openssh.authorizedKeys.keys = [
                # The two nire-lysithea entries are DIFFERENT KEYS, not a
                # duplicate to tidy up. They differ only by a `.local` suffix in
                # the comment field, which is how the gap below went unnoticed.
                #
                # This one -- bare `elly@nire-lysithea` -- has no private half on
                # nire-lysithea as of 2026-08-21: no matching file in ~/.ssh
                # (id_ed25519 is the only keypair there, dated Sep 2024) and
                # `ssh-add -l` reports no identities. Where it went is unknown;
                # it predates the flake-parts port. Kept rather than deleted
                # because it cannot be proven dead from lysithea, and removing an
                # authorized key you cannot account for is how you discover it
                # was load-bearing. Delete it once you know what held it.
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea"

                # The key actually on nire-lysithea, added 2026-08-21.
                # SHA256:fUxn4S79MlIYFrd4yKKy0d8RmE0J59bdeGXg36c6dgw
                # Until this landed, the laptop this repo is edited from could not
                # ssh to ANY host in the fleet -- publickey is the only accepted
                # method (AuthenticationMethods below), so the mismatch was a
                # total lockout, not a fallback to password.
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACfyClu9egyamrth/SspY6wPA78o8sJuSR7jyBX42ex elly@nire-lysithea.local"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFfyxNzG07CdeNEZof+l49+fqx+2E79gmYvnRqiGdNp elly@nire-tenacity"
                "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFwOpjlybwn/ebH4KKoAcsVQ41wxeqD41CyfIALkV61t8BXV2Wf2pdnrBMxLuHHi9+uq7DlGs2nrW938WtaHvRo= elly@deja"
                ];
            };
        };
}
