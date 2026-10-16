# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # nix package version diff
        home.packages = with pkgs; [
            nvd
        ];
    };
}
