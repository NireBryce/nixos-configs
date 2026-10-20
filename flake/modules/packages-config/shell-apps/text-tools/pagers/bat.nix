# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # `bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat
        home.packages = with pkgs; [
            bat
        ];
    };
}
