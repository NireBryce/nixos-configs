# desc = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    jc
];
in
{
    home.packages = packageList;
}
;}
