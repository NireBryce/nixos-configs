# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # `rg` is a much faster and more powerful grep alternative
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
