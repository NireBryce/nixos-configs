# desc = "`find` alternative";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    fd
];
in
{
    home.packages = packageList;
}
;}
