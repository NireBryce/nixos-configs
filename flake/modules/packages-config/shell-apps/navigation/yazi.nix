# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # yazi - file browser
        home.packages = with pkgs; [
            yazi
        ];
    };
}
