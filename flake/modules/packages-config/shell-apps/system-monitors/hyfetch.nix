# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # neofetch replacement https://github.com/hykilpikonna/HyFetch
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
