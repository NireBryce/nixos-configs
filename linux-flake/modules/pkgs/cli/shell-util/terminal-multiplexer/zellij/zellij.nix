{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.zellij ];

    flake.modules.homeManager.zellij =
# desc = "";
{ pkgs, ... }:
{
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
}
;}
