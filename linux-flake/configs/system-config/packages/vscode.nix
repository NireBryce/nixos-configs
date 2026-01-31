{
    ...
}:
{
    flake.modules.nixos.core.vscode = { pkgs, ... }: {
        # vscode errata, actual vscode definition in `home-manager/user-elly/packages/dev/vscode`
        environment.sessionVariables.NIXOS_OZONE_WL = "1";
        environment.systemPackages = with pkgs; [
            nixd # nix LSP
        ];

        programs.nix-ld.enable = true;      # Needed for VSCode remote connection, etc
    };
}
