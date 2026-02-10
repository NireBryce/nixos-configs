# github-desktop - github gui
{ den.bundles.hm.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    github-desktop
];
in
{
    home.packages = packageList;
}
;}
