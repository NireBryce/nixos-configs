{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.jc ];

    flake.modules.homeManager.jc =
# desc = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        jc
    ];
}
;}
