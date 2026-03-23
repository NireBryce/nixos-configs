# desc = "gnu which"; # TODO: better desc
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        which
    ];
}
