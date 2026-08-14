{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
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

                    # prefetch is the only maintenance task that touches the network,
                    # and `origin` here is an ssh remote (git@github.com). The timer
                    # runs as a systemd user unit, which has no SSH_AUTH_SOCK, so
                    # prefetch cannot authenticate and would fail on every hourly run
                    # -- recreating exactly the always-failing timer this replaced.
                    # The local-only tasks are the ones worth having anyway.
                    maintenance.prefetch.enabled = false;
                };
                signing = {
                    key = "~/.ssh/id_ed25519";
                    signByDefault = builtins.stringLength "~/.ssh/id_ed25519" > 0;
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
