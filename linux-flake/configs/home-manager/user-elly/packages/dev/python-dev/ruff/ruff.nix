# ruff - python linter
{ flake.modules.homeManager.development.python.ruff = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ruff
];
in
{
    home.packages = packageList;
}
;}
