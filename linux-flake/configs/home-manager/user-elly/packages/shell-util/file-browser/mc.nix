# desc = "midnight commander file browser";
{ flake.modules.homeManager.shellUtil.fileBrowser.mc =
{ pkgs, ... }:
let packageList = with pkgs; [
    mc
];

in

{
    home.packages = packageList;
}
;}
