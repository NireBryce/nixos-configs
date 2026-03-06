# ruff - python linter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ruff
    ];
}
