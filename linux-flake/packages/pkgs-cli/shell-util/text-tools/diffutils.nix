# desc = "`diff` utils";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        diffutils
    ];
}
