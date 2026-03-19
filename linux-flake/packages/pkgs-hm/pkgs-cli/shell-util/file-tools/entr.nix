# desc = "run commands when file changes";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        entr
    ];
}
