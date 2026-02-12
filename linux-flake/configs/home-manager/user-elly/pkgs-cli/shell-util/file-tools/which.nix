# desc = "gnu which"; # TODO: better desc
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    which
];
in
{
    home.packages = packageList;
}
;}
