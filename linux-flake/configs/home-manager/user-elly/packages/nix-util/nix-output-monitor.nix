# desc = "`nom`"; # TODO: better desc
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-output-monitor
];
in
{
    home.packages = packageList;
}
;}
