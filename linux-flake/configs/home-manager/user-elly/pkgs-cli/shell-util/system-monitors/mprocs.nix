# desc = "run multiple commands in parallel";
{ pkgs, ... }:
{ den.aspects.hm.provides.pkgs-cli = 
let packageList = with pkgs; [
    mprocs
];
in
{
    home.packages = packageList;
}
;}
