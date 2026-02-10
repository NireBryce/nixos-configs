# aria2 -cli download manager
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    aria2
];
in
{
    home.packages = packageList;
}
;}
