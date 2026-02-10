# kanata - input-level keybinding, platform independent
{ den.bundles.hm.keybinding =
{ pkgs, ... }:
let packageList = with pkgs; [
    kanata
];
in
{
    home.packages = packageList;
}
;}
