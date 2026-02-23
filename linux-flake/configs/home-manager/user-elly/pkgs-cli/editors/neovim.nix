# neovim - it's like vim but heavier
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    neovim
];
in
{
    home.packages = packageList;
}
;}
