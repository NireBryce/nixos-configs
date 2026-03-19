# desc = "`rg` much faster grep alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ripgrep
    ];
}
