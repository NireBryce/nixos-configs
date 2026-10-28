# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = {
        # package summary: nh -- Nix rebuild helper CLI, with scheduled store cleanup
        programs.nh = {
            enable = true;
            clean.enable = true;
            clean.extraArgs = "--keep-since 7d --keep 5";
            # flake           = "/home/elly/nixos"; # TODO: see if this can be dynamically set to this flake's path
        };
    };
}
