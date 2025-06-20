# desc = "Audacity audio editor";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        audacity
    ];
in 
{
home.packages = packageList;
}
