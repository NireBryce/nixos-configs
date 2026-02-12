# desc = "nix man pages, kinda";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    manix
];
in
{
    home.packages = packageList;
}
;}
