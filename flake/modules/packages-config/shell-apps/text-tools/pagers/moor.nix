# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: { 
        # description = "better pager for some things https://github.com/walles/moor";
        home.packages = with pkgs; [
            moor # moar renamed to moor https://github.com/walles/moor/pull/305
        ];
    };
}
