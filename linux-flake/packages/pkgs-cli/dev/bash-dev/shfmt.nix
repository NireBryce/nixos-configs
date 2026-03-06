# shellfmt shellscript formatter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
