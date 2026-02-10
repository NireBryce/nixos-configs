{ den.bundles.hm.claude =
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
