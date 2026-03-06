# desc = "`nom`"; # TODO: better desc
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-output-monitor
    ];
}
