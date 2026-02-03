# nixfmt - .nix file formatter";
{ flake.modules.homeManager.development.nix.nixfmt =
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
;}
