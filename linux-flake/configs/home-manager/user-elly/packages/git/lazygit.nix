# lazygit - TUI git interface
{ den.bundles.hm.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    lazygit
];
in
{
    home.packages = packageList;
}
;}
