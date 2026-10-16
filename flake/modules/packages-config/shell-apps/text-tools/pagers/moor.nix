# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # description = "better pager for some things https://github.com/walles/moor";
        home.packages = with pkgs; [
            moor # moar renamed to moor https://github.com/walles/moor/pull/305
        ];
    };
}
