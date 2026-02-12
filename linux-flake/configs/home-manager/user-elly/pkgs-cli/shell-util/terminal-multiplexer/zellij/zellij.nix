# desc = "";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    zellij
];
in
{
home.packages = packageList;

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
