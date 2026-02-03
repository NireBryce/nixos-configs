# desc = "count lines of code";
{ flake.modules.homeManager.packages.shellUtil.tokei =
{ pkgs, ... }:
let packageList = with pkgs; [
    tokei
];
in
{
    home.packages = packageList;
}
;}
