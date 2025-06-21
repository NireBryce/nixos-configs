# desc = "TUI git interface";
{ pkgs, ... }:
let packageList = with pkgs; [
    lazygit
];
in
{
    home.packages = packageList;
}
