# desc = "`nom`"; # TODO: better desc
{ flake.modules.homeManager.packages.nix.nix-output-monitor =
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-output-monitor
];
in
{
    home.packages = packageList;
}
;}
