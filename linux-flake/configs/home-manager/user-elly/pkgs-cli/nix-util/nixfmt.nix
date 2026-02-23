# nixfmt - .nix file formatter";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
;}
