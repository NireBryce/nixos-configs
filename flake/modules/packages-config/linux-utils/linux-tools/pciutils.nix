# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # `lspci`
        home.packages = with pkgs; [
            pciutils
        ];
    };
}
