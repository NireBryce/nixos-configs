# desc = "nix man pages, kinda";
{ pkgs, ... }:
let packageList = with pkgs; [
    manix
];
in
{
    home.packages = packageList;
}
