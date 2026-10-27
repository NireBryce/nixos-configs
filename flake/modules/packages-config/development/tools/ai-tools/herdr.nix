# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
            # package summary: herdr: agent multiplexer that lives in your terminal
            home.packages = with pkgs; [
                herdr
            ];
    };
}
