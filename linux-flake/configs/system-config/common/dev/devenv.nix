{ pkgs, ... }:
let
    packageList = with pkgs; [
        devenv
    ];
in
{
    environment.systemPackages = packageList;
}
