# desc = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    jc
];
in
{
    home.packages = packageList;
}
;}
