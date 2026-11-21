# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: let
        # git runs this in place of ssh-keygen for every SSH signature
        # (`gpg.ssh.program`) and for verification calls (`-Y verify` etc.).
        #
        # - Non-interactive sessions (coding agents, CI) have no
        #   SSH_AUTH_SOCK, so point it at the SSH agent's socket when that
        #   socket exists. On cube there is none and the key is a file.
        # - ssh-keygen runs as a child, not `exec`, so a hint can follow it.
        #   Its exit status is passed through unchanged; git reads the
        #   signature from a file only after a zero exit.
        # - The hint prints only for a failed `-Y sign`, only to stderr, and
        #   is a fixed string: no arguments, environment or ssh-keygen output
        #   go into it, because agents read it and treat it as instructions.
        #   It says nothing about retrying: each attempt can open a new
        #   approval prompt for the user.
        # - ssh-keygen is called by store path, not looked up on PATH.
        # - No `${` in the script text: inside this `''` string it would be a
        #   Nix interpolation.
        sshSign = pkgs.writeShellScript "git-ssh-sign" ''
            if [ -z "$SSH_AUTH_SOCK" ] && [ -S "$HOME/.bitwarden-ssh-agent.sock" ]; then
                SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
                export SSH_AUTH_SOCK
            fi
            ${pkgs.openssh}/bin/ssh-keygen "$@"
            status=$?
            if [ "$status" -ne 0 ] && [ "$1" = "-Y" ] && [ "$2" = "sign" ]; then
                printf '%s\n' "git-ssh-sign: ssh-keygen returned no signature. The signing request may have been denied or timed out, or the key passphrase was not entered. Each attempt can open a new approval prompt. See wiki/ssh/commit-signing.md." >&2
            fi
            exit "$status"
        '';
    in {
        home.file."./.gitconfig".source = ./.gitconfig;

        programs.git = {        # User-specific git config
            enable = true;
            settings = {
                alias = {
                    pushall = "!git remote | xargs -L1 git push --all";
                    graph = "log --decorate --oneline --graph";
                    add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
                };
                user = {
                    name = "Nire Bryce";
                    email = "nire@computernope.net";
                };

                feature.manyFiles = true;
                init.defaultBranch = "main";
                gpg.format = "ssh";
                gpg.ssh.program = "${sshSign}";

                # prefetch is the only maintenance task that touches the network,
                # and `origin` here is an ssh remote (git@github.com). The timer
                # runs as a systemd user unit, which has no SSH_AUTH_SOCK, so
                # prefetch cannot authenticate and would fail on every hourly run
                # -- recreating exactly the always-failing timer this replaced.
                # The local-only tasks are the ones worth having anyway.
                maintenance.prefetch.enabled = false;
            };
            signing = {
                # The public half of the auth key: the private half is held
                # by the session's SSH agent, which ssh-keygen consults when
                # asked to sign for a public key it serves.
                key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal";
                # Every commit signs with the SSH auth key, deliberately --
                # including agent-made ones. git fails a signing commit
                # loudly if the key is ever absent; the old
                # `stringLength "~/.ssh/id_ed25519" > 0` "check" could only
                # ever be true (it measured the literal, not the disk).
                signByDefault = true;
            };

            lfs.enable = true;
            ignores = [ ".direnv" "result" ];

            # Home Manager generates the `git-maintenance@` unit and its timers,
            # so the git store path in ExecStart is rewritten on every switch.
            #
            # Do NOT set this up with `git maintenance start` instead. That bakes
            # the current git's store path into a unit in ~/.config/systemd/user/
            # and nothing ever updates it, so the timer starts failing with
            # status=203/EXEC as soon as that git is garbage collected.
            maintenance = {
                enable       = true;
                # Only the live config repo. The previous hand-written list also
                # named /home/elly/nixos (a stale copy) and a fleek dir that is gone.
                repositories = [
                    "/home/elly/projects/nixos/nixos-configs"
                ];
            };
        };
    };
}
