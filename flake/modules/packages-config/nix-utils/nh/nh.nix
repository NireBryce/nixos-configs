# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = {
        programs.nh = {
            enable = true;
            clean.enable = true;
            clean.extraArgs = "--keep-since 7d --keep 5";
            # flake           = "/home/elly/nixos"; # TODO: see if this can be dynamically set to this flake's path
        };
    };
}
