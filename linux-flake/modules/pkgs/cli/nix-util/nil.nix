{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nil ];

    flake.modules.homeManager.nil =
# nil - a nix LSP server
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nil
    ];
}
;}
