# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # neovim - it's like vim but heavier
        home.packages = with pkgs; [ neovim ];
    };
}
