# neovim - it's like vim but heavier
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        neovim
    ];
}
