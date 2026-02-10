# desc = "list open files https://linux.die.net/man/1/lsof";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    lsof
];
in
{
    home.packages = packageList;
}
;}
