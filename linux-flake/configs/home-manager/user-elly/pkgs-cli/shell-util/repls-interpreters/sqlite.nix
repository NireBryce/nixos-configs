# desc = "sqlite";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    sqlite
];
in
{
    home.packages = packageList;
}
;}
