# desc = "nix man pages, kinda";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    manix
];
in
{
    home.packages = packageList;
}
;}
