{
    pkgs,
    ...
}:
 
{
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    
    programs.nix-ld.enable = true;      # Needed for VSCode remote connection, etc
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
}
