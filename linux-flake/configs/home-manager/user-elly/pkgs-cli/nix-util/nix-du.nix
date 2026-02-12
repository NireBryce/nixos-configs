# desc = "nix-store analysis";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-du
];
in
{
    home.packages = packageList;
}
;}
