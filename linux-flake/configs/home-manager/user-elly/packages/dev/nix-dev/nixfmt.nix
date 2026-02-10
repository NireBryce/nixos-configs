# nixfmt - .nix file formatter";
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
;}
