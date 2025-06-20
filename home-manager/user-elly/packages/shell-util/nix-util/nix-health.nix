# desc = "check nix issues";
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-health
];
in
{
    home.packages = packageList;
}
