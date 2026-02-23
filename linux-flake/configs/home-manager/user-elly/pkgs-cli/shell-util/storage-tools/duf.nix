# desc = "`df` alternative";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    duf
];
in
{
    home.packages = packageList;
}
;}
