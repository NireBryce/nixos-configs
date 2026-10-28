# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
            # package summary: herdr: agent multiplexer that lives in your terminal
            home.packages = with pkgs; [
                herdr
            ];
    };
}
