# shellfmt shellscript formatter
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shfmt
    ];
}
;}
