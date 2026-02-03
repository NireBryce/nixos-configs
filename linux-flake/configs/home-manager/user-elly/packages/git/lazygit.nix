# lazygit - TUI git interface
{ flake.modules.homeManager.packages.git.lazygit =
{ pkgs, ... }:
let packageList = with pkgs; [
    lazygit
];
in
{
    home.packages = packageList;
}
;}
