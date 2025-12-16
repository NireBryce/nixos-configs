{ pkgs, ... }:
let
    packageList = with pkgs; [
        devenv
    ];
in
{
    environment.systemPackages = packageList;
    cachix.enable = false; # disable cachix caching
}
