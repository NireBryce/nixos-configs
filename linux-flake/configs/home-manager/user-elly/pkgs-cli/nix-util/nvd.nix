# desc = "nix package version diff";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nvd
];
in
{
    home.packages = packageList;
}
;}
