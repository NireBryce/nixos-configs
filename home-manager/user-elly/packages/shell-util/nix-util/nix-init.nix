# desc = "nix packages from URLs"; # TODO: do I need this?
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-init
];
in
{
    home.packages = packageList;
}
