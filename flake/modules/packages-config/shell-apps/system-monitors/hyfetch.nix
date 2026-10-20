# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # neofetch replacement https://github.com/hykilpikonna/HyFetch
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
