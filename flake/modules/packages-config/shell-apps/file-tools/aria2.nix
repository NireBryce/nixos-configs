# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # aria2 -cli download manager
        home.packages = with pkgs; [
            aria2
        ];
    };
}
