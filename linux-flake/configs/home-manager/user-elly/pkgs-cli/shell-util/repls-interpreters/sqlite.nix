# desc = "sqlite";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    sqlite
];
in
{
    home.packages = packageList;
}
;}
