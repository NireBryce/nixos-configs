# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # list open files https://linux.die.net/man/1/lsof
        home.packages = with pkgs; [
            lsof
        ];
    };
}
