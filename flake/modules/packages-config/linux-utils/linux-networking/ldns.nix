# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: ldns -- DNS library; provides `drill`, a `dig` alternative
        # provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/
        home.packages = with pkgs; [
            ldns
        ];
    };
}
