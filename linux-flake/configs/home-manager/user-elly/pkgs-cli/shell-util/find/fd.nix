# desc = "`find` alternative";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    fd
];
in
{
    home.packages = packageList;
}
;}
