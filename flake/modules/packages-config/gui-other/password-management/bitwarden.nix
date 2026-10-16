# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # bitwarden - password manager https://bitwarden.com/
        home.packages = with pkgs; [
            bitwarden-desktop
        ];
    };
}
