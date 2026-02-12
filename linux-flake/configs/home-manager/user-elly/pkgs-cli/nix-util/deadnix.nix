# desc = "scan for 'dead' (uncalled) nix code";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    deadnix
];
in
{
    home.packages = packageList;
}
;}
