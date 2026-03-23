# tldr - community provided man pages
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        tldr
    ];
}
