{
    ...
}:
{
    imports = [
        ./xdg.nix
        ./nix-utilities.nix
    ];

    # utilities
    services.fwupd.enable = true;           # fwupd
    programs.nix-ld.enable = true;          # Needed for VSCode remote connection
    programs.kdeconnect.enable = true;      # kde connect
    

}
