# desc = "`nom`"; # TODO: better desc
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-output-monitor
];
in
{
    home.packages = packageList;
}
