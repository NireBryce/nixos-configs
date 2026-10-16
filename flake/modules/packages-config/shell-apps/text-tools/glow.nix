# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # terminal markdown viewer https://github.com/charmbracelet/glow
        home.packages = with pkgs; [
            glow
        ];
    };
}
