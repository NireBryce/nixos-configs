# shellfmt shellscript formatter
{ flake.modules.homeManager.development.shellscript.shfmt =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
;}
