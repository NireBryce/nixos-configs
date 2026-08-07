{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.shfmt ];

    flake.modules.homeManager.shfmt =
# shellfmt shellscript formatter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
;}
