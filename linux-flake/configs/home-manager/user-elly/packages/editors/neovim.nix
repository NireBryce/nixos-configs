# neovim - it's like vim but heavier
{ flake.modules.homeManager.packages.editors.neovim =
{ pkgs, ... }:
let packageList = with pkgs; [
    neovim
];
in
{
    home.packages = packageList;
}
;}
