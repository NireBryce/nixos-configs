# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: { 
        # `bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat
        home.packages = with pkgs; [
            bat
        ];
    };
}
