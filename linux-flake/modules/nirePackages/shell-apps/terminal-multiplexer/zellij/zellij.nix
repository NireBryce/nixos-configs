{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "zellij terminal multiplexer";
            home.packages = with pkgs; [
                zellij
            ];

            home.file = {
                "./.config/zellij/config.kdl" = {
                    source = ./config/config.kdl;
                };
            };

            programs.zellij = {
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;
            };
        };
    };
}
