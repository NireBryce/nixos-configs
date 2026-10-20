# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # count lines of code
        home.packages = with pkgs; [
            tokei
        ];
    };
}
