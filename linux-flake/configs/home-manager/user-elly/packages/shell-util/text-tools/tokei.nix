# desc = "count lines of code";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    tokei
];
in
{
    home.packages = packageList;
}
;}
