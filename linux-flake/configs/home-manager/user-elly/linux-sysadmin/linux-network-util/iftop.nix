# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    iftop
];
in
{
    home.packages = packageList;
}
;}
