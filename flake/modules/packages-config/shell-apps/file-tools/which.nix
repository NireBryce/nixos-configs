# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ 
    homeManager = { pkgs, ... }: {
        # package summary: which -- prints the path a command name resolves to
        # which - find the location of a given command's binary
        home.packages = with pkgs; [
            which
        ];
    };
}
