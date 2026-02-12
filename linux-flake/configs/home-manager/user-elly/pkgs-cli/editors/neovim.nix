# neovim - it's like vim but heavier
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    neovim
];
in
{
    home.packages = packageList;
}
;}
