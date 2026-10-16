# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # neovim - it's like vim but heavier
        home.packages = with pkgs; [ neovim ];
    };
}
