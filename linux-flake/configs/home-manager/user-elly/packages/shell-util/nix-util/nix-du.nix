# desc = "nix-store analysis";
{ flake.modules.homeManager.packages.nix.nix-du =
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-du
];
in
{
    home.packages = packageList;
}
;}
