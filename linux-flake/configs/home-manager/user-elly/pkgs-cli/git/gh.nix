# gh - github-cli
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    gh
];
in
{
    home.packages = packageList;
}
;}
