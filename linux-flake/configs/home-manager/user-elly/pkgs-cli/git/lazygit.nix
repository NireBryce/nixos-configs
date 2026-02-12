# lazygit - TUI git interface
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    lazygit
];
in
{
    home.packages = packageList;
}
;}
