# desc = "sqlite";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        sqlite
    ];
}
