{ self, inputs, ...}:
{ flake.modules.nixos.vscode =
{ pkgs, ... }:

{
    

    # vscode settings
    environment.sessionVariables.NIXOS_OZONE_WL = "1"; # TODO: this is erroring benignly
    environment.systemPackages = with pkgs; [
        nixd # nix LSP
    ];

    programs.nix-ld.enable = true;      # Needed for VSCode remote connection, etc
}
;}
