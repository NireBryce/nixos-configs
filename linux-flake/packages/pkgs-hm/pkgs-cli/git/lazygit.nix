# lazygit - TUI git interface
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        lazygit
    ];
}
