# yazi - file browser MAKE BETTER DESC
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    yazi
];
in
{
    home.packages = packageList;
}
;}
