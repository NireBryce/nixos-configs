# desc = "midnight commander file browser";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    mc
];

in

{
    home.packages = packageList;
}
;}
