# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # run multiple commands in parallel
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
