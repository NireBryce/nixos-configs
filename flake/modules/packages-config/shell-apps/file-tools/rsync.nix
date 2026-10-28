# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: rsync -- incremental file copy and sync, local or remote
        # rsync - back in my day we transfered our files uphill both ways
        home.packages = with pkgs; [
            rsync
        ];
    };
}
