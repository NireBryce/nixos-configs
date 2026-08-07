{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.claude ];

    flake.modules.homeManager.claude =
{ pkgs, ... }:
let 
    packageList = with pkgs; [
        claude-code
    ];
in
{
    home.packages = packageList;
}
;}
