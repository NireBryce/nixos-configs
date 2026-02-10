# neovim - it's like vim but heavier
{ den.bundles.hm.editors =
{ pkgs, ... }:
let packageList = with pkgs; [
    neovim
];
in
{
    home.packages = packageList;
}
;}
