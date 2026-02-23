# desc = "run multiple commands in parallel";
{ ... }:
{ den.aspects.pkgs-cli.homeManager =
{ pkgs, ... }:
let packageList = with pkgs; [
    mprocs
];
in
{
    home.packages = packageList;
}
;}
