# desc = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    jc
];
in
{
    home.packages = packageList;
}
;}
