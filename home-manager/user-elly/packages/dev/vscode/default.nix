{
    pkgs,
    ...
}:
 
{
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = with pkgs; [
        nixd # nix LSP
    ];
    programs.nix-ld.enable = true;      # Needed for VSCode remote connection, etc
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
    
}
