{
    pkgs,
    ...
}:
 
{
    # other settings in system-config/dev/vscode-setup
    # TODO: consider merging home-manager and system-config under same flake
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
    
}
