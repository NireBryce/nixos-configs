# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            xdg-utils
        ];
    };
}
