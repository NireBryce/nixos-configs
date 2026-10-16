# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # network monitor https://pdw.ex-parrot.com/iftop/
        home.packages = with pkgs; [
            iftop
        ];
    };
}
