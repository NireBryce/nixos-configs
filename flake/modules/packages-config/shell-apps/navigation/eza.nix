# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { 
        # package summary: eza -- `ls` replacement, maintained fork of exa
        # `exa` fork, which is an ls alternative
        programs.eza = {
            enable = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
            icons = "auto";
            colors = "auto";
            git = true;
            extraOptions = [
            "-1" # portrait mode
            "--header"
            "--hyperlink"
            "--group-directories-first"
            ];
        };
    };
}
