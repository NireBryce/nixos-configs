# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # note: this is also installed as a system package, does that matter?
        home.packages = with pkgs; [ 
            firefox 
        ];
    };
}
