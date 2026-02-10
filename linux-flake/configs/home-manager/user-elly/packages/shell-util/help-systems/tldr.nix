# tldr - community provided man pages
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    tldr
];
in
{
    home.packages = packageList;
}
;}
