{ pkgs, ... }:
let
    packageList = with pkgs; [
        ulauncher
    ];
in
{
    home.packages = packageList;
}
