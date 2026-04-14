{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
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
}
