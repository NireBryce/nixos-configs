# desc = "home-manager instance of python3";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        python3
    ];
}
