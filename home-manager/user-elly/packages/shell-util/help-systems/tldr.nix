# desc = "tldr - community provided man pages";
{ pkgs, ... }:
let packageList = with pkgs; [
    tldr
];
in
{
    home.packages = packageList;
}
