# desc = "nix-store analysis";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-du
];
in
{
    home.packages = packageList;
}
;}
