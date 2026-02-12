# desc = "`nom`"; # TODO: better desc
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-output-monitor
];
in
{
    home.packages = packageList;
}
;}
