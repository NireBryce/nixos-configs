# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # system stats http://sebastien.godard.pagesperso-orange.fr/
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
