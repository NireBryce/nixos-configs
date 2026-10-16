# Module file: named after this file; why it looks this way: wiki/module-files.md
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
