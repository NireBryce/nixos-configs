# desc = "sqlite";
{ flake.modules.homeManager.packages.shellUtil.sqlite =
{ pkgs, ... }:
let packageList = with pkgs; [
    sqlite
];
in
{
    home.packages = packageList;
}
;}
