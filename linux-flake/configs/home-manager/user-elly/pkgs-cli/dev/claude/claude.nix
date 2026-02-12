{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let 
    packageList = with pkgs; [
        claude-code
    ];
in
{
    home.packages = packageList;
}
;}
