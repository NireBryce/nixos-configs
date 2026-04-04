# desc = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        jc
    ];
}
