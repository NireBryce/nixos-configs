# desc = "scan for 'dead' (uncalled) nix code";
{ pkgs, ... }:
let packageList = with pkgs; [
    deadnix
];
in
{
    home.packages = packageList;
}
