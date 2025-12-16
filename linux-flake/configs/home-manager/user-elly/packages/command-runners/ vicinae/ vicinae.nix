{ pkgs, ... }:
let
    packageList = with pkgs; [
        vicinae
    ];
in
{
    home.packages = packageList;
}
