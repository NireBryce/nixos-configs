# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # run commands when file changes
        home.packages = with pkgs; [
            entr
        ];
    };
}
