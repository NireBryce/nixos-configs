# desc = "gnu which"; # TODO: better desc
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    which
];
in
{
    home.packages = packageList;
}
;}
