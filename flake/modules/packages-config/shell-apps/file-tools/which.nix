# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # which - find the location of a given command's binary
        home.packages = with pkgs; [
            which
        ];
    };
}
