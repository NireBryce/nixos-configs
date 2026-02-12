# desc = "`du` alternative";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    dust
];
in
{
    home.packages = packageList;
}
;}
