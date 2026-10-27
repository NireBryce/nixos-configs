# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { 
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
