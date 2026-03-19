# vscode - it is what it is
# other settings in system-config/dev/vscode-setup
# checkme: consider merging home-manager and system-config under same flake
# TODO: can you remove this?
{ pkgs, ... }:

{
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };

    # vscode settings
    environment.sessionVariables.NIXOS_OZONE_WL = "1"; # TODO: this is erroring benignly
    environment.systemPackages = with pkgs; [
        nixd # nix LSP
    ];

    programs.nix-ld.enable = true;      # Needed for VSCode remote connection, etc
}
