# ruff - python linter
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ruff
];
in
{
    home.packages = packageList;
}
;}
