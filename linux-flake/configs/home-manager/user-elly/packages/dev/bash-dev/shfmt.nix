# shellfmt shellscript formatter
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
;}
