# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # `bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat
        home.packages = with pkgs; [
            bat
        ];
    };
}
