# desc = "nix-store analysis";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-du
];
in
{
    home.packages = packageList;
}
;}
