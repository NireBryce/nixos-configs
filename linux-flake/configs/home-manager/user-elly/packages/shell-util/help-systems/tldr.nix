# tldr - community provided man pages
{ flake.modules.homeManager.shellUtil.helpSystems.tldr =
{ pkgs, ... }:
let packageList = with pkgs; [
    tldr
];
in
{
    home.packages = packageList;
}
;}
