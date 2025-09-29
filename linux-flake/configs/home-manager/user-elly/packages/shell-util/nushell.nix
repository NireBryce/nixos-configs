# desc = "
#    nushell - the next generation shell
#    hint: nushell -c for tabular display in any shell
# ";
{ pkgs, ... }:
let packageList = with pkgs; [
    nushell
];
in
{
    home.packages = packageList;
}
