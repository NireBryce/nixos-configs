# desc = "show filetype";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        file
    ];
}
