# lazygit - TUI git interface
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    lazygit
];
in
{
    home.packages = packageList;
}
;}
