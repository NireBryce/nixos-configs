# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # run multiple commands in parallel
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
