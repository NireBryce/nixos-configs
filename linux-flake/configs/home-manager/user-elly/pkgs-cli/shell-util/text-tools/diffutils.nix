# desc = "`diff` utils";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    diffutils
];
in
{
    home.packages = packageList;
}
;}
