# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # yazi - file browser
        home.packages = with pkgs; [
            yazi
        ];
    };
}
