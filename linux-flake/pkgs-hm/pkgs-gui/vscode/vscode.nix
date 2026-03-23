{ pkgs, ...}:
{
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
}

    # TODO: this is needed for vscode to work do not remove this package
