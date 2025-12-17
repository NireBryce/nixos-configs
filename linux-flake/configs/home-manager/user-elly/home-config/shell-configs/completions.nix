{ pkgs, ... }:
let 
    packageList = with pkgs; [
        cod
    ];
in
{
    home.packages = packageList;
}
