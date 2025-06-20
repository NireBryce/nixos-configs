# desc = "nix-store analysis";
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-du
];
in
{
    home.packages = packageList;
}
