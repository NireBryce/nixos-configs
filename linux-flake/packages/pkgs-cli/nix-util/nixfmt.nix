# nixfmt - .nix file formatter";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nixfmt
    ];
}
