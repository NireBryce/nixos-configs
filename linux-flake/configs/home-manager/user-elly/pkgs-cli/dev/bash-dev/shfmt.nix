# shellfmt shellscript formatter
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
;}
