# desc = "`rg` much faster grep alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    ripgrep
];
in
{
    home.packages = packageList;
}
