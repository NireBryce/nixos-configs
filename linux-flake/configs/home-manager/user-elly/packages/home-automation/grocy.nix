{ pkgs, ... }:
let
    packageList = with pkgs; [
        grocy
    ];
in 
{
    home.packages = packageList;
}
