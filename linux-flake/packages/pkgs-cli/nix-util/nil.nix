# nil - a nix LSP server
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nil
    ];
}
