# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = { pkgs, ... }: {
        # midnight commander file browser
        home.packages = with pkgs; [
            mc
        ];
    };
}
