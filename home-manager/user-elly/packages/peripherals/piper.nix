# desc = " logitech/razer mouse manager https://github.com/soxoj/piper";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        piper
    ];
in 
{
    home.packages = packageList;
}
