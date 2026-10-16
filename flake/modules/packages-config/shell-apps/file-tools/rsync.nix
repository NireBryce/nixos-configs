# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # rsync - back in my day we transfered our files uphill both ways
        home.packages = with pkgs; [
            rsync
        ];
    };
}
