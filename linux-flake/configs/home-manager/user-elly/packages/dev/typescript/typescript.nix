# typescript - it's typescript
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    typescript
];
in
{   
    home.packages = packageList;
}
;}
