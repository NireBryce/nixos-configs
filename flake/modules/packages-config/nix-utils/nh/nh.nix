# dirs-as-categories: the module is named after this file; its categories are the folders above it
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
