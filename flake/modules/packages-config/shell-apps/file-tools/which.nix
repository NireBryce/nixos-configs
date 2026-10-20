# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = { pkgs, ... }: {
        # which - find the location of a given command's binary
        home.packages = with pkgs; [
            which
        ];
    };
}
