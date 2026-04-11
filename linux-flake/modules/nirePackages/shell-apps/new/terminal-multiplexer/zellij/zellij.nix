{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "zellij terminal multiplexer";
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
