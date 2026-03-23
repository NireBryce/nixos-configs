# desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        bat
    ];
}
