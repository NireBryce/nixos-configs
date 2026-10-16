# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # `find` alternative
        home.packages = with pkgs; [
            fd
        ];
    };
}
