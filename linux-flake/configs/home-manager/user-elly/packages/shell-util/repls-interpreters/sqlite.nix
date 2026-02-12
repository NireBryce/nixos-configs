# desc = "sqlite";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    sqlite
];
in
{
    home.packages = packageList;
}
;}
