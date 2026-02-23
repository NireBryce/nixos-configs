# desc = "`nom`"; # TODO: better desc
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-output-monitor
];
in
{
    home.packages = packageList;
}
;}
