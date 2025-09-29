# desc = "io monitoring http://guichaz.free.fr/iotop";
{ pkgs, ... }:
let packageList = with pkgs; [
    iotop
];
in
{
    home.packages = packageList;
}
