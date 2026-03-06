# desc = "`find` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        fd
    ];
}
