# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # run commands when file changes
        home.packages = with pkgs; [
            entr
        ];
    };
}
