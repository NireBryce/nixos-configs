# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # `htop` alternative
        home.packages = with pkgs; [
            btop
        ];
    };
}
