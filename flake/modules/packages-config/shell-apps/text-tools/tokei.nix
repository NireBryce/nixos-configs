# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # count lines of code
        home.packages = with pkgs; [
            tokei
        ];
    };
}
