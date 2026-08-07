{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.uv ];

    flake.modules.homeManager.uv =
# uv - python version-, venv-, and packaging-management tool
{ pkgs, ... }:
{   
    home.packages = with pkgs; [
        uv
    ];
}
;}
