# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: python3 -- Python 3 interpreter, user-level install
        # home-manager instance of python3
        home.packages = with pkgs; [
            python3
        ];
    };
}
