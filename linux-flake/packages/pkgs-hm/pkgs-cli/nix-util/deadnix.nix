# desc = "scan for 'dead' (uncalled) nix code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        deadnix
    ];
}
