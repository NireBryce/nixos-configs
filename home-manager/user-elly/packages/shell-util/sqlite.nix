# desc = "sqlite";
{ pkgs, ... }:
let packageList = with pkgs; [
    sqlite
];
in
{
    home.packages = packageList;
}
