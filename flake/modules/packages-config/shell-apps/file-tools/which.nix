# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ 
    homeManager = { pkgs, ... }: {
        # which - find the location of a given command's binary
        home.packages = with pkgs; [
            which
        ];
    };
}
