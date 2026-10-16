# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # per-character in-line diff
        home.packages = with pkgs; [
            riffdiff
        ];
    };
}
