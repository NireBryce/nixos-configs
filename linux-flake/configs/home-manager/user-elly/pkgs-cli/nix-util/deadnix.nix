# desc = "scan for 'dead' (uncalled) nix code";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    deadnix
];
in
{
    home.packages = packageList;
}
;}
