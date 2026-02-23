# ruff - python linter
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ruff
];
in
{
    home.packages = packageList;
}
;}
