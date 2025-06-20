# desc = ".nix file formatter";
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
