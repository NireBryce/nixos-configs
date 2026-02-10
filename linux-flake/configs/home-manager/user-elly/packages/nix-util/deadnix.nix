# desc = "scan for 'dead' (uncalled) nix code";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    deadnix
];
in
{
    home.packages = packageList;
}
;}
