# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # `du` alternative
        home.packages = with pkgs; [
            dust
        ];
    };
}
