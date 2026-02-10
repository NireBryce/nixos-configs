# desc = "nix package version diff";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nvd
];
in
{
    home.packages = packageList;
}
;}
