# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # midnight commander file browser
        home.packages = with pkgs; [
            mc
        ];
    };
}
