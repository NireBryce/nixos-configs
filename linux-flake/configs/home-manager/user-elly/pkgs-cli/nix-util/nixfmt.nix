# nixfmt - .nix file formatter";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
;}
