# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: { 
        # package summary: hyfetch -- neofetch fork: system info with pride flags
        # neofetch replacement https://github.com/hykilpikonna/HyFetch
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
