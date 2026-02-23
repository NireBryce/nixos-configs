# desc = "
#    nushell - the next generation shell
#    hint: nushell -c for tabular display in any shell
# ";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nushell
];
in
{
    home.packages = packageList;
}
;}
