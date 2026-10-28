# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: jc -- converts command output and file formats to JSON
        # jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc
        home.packages = with pkgs; [
            jc
        ];
    };
}
