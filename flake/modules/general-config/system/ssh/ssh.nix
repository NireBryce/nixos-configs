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
                PermitRootLogin = "no"; # default "prohibit-password"; root has no keys to allow
                };

                # Only the declared keys below, never ~/.ssh/authorized_keys:
                # anything running as the user (an agent, opencode on cube)
                # could otherwise add a key that survives every switch. No
                # host had that file when this was set (2026-09-26).
                authorizedKeysInHomedir = false;
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

                # The key on nire-lysithea, added 2026-08-21.
                # SHA256:fUxn4S79MlIYFrd4yKKy0d8RmE0J59bdeGXg36c6dgw
                # Until this landed, the laptop this repo is edited from could not
                # ssh to ANY host in the fleet -- publickey is the only accepted
                # method (AuthenticationMethods below), so the mismatch was a
                # total lockout, not a fallback to password.
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACfyClu9egyamrth/SspY6wPA78o8sJuSR7jyBX42ex elly@nire-lysithea.local"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFfyxNzG07CdeNEZof+l49+fqx+2E79gmYvnRqiGdNp elly@nire-tenacity"
                # deja is the iPad.
                "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFwOpjlybwn/ebH4KKoAcsVQ41wxeqD41CyfIALkV61t8BXV2Wf2pdnrBMxLuHHi9+uq7DlGs2nrW938WtaHvRo= elly@deja"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbt2aSZdU5732g4yNXo/pOnl2DZDMKKP4cPPHyAcIkF elly@nire-iona-termius"
                ];
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-26 — removed a second lysithea key, bare `elly@nire-lysithea`
# (ssh-ed25519 ...AAAAILk2lST7), next to the `.local` one above. It differed
# only by that suffix in the comment field, which is how it went unnoticed,
# and had no private half on lysithea as of 2026-08-21 (id_ed25519 was the
# only keypair there, `ssh-add -l` empty). Predated the flake-parts port;
# nothing ever accounted for it.
