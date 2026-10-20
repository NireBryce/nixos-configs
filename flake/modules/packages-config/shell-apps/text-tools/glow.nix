# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # terminal markdown viewer https://github.com/charmbracelet/glow
        home.packages = with pkgs; [
            glow
        ];
    };
}
