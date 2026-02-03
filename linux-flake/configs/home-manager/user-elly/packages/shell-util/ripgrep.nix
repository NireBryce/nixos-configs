# desc = "`rg` much faster grep alternative";
{ flake.modules.homeManager.packages.shellUtil.ripgrep =
{ pkgs, ... }:
let packageList = with pkgs; [
    ripgrep
];
in
{
    home.packages = packageList;
}
;}
