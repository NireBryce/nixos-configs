{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nix-du ];

    flake.modules.homeManager.nix-du =
# desc = "nix-store analysis"; 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-du
    ];
}
;}
