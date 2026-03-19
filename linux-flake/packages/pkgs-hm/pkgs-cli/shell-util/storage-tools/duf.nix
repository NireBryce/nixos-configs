# desc = "`df` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        duf
    ];
}
