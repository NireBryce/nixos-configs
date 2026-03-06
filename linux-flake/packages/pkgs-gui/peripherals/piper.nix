# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        piper
    ];
}
