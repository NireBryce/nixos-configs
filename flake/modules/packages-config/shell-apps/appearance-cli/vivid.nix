# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # vivid - LS_COLORS generator
        home.packages = with pkgs; [
            vivid
        ];
    };
}
