# desc = "its like curl but different https://www.gnu.org/software/wget/";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    wget
];
in
{
    home.packages = packageList;
}
;}
