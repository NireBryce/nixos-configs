{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nushell ];

    flake.modules.homeManager.nushell =
# desc = "
#    nushell - the next generation shell
#    hint: nushell -c for tabular display in any shell
# ";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nushell
    ];
}
;}
