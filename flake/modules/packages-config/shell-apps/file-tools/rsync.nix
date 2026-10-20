# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # rsync - back in my day we transfered our files uphill both ways
        home.packages = with pkgs; [
            rsync
        ];
    };
}
