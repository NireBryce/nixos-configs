{ ... }:
# other settings in system-config/dev/vscode-setup
# TODO: consider merging home-manager and system-config under same flake
{
    # desc = "vscode-fhs";
    flake.modules.homeManager.base =
    { pkgs, ... }:

    {
        programs.vscode = {
            enable = true;
            package = pkgs.vscode-fhs;
        };
    };
}
