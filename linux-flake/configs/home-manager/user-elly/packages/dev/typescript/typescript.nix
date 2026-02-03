# typescript - it's typescript
{ flake.modules.homeManager.development.typescript =
{ pkgs, ... }:
let packageList = with pkgs; [
    typescript
];
in
{   
    home.packages = packageList;
}
;}
