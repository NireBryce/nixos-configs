# desc = "
#    nushell - the next generation shell
#    hint: nushell -c for tabular display in any shell
# ";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    nushell
];
in
{
    home.packages = packageList;
}
;}
