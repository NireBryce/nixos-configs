# desc = "
#    nushell - the next generation shell
#    hint: nushell -c for tabular display in any shell
# ";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nushell
    ];
}
