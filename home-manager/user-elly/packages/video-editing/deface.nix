{ pkgs, ... }:
# Deface face redaction
let
    packageList = with pkgs; [
        deface
    ];
in 
{
    home.packages = packageList;
}
