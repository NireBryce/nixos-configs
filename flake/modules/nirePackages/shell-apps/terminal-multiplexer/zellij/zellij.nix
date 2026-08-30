{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # zellij terminal multiplexer
            home.packages = with pkgs; [
                zellij
            ];

            home.file = {
                "./.config/zellij/config.kdl" = {
                    # darwin: pbcopy instead of relying on zellij's default OSC 52
                    # copy, which needs "Applications in terminal may access
                    # clipboard" enabled in iTerm2 prefs to land in the real
                    # clipboard. See config.kdl's own copy_command comment.
                    text = builtins.readFile ./config/config.kdl
                        + lib.optionalString pkgs.stdenv.isDarwin ''
                            copy_command "pbcopy"
                        '';
                };
            };

            programs.zellij = {
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;
            };
        };
}
