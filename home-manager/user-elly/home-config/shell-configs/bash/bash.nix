{ ... }:
{
    # desc = "bash configs";
    flake.modules.homeManager.base =
    { ... }:

    {
        home.file = {
            "./.bash_logout"      .source = ./config/.bash_logout;
            "./.bash_profile"     .source = ./config/.bash_profile;
            "./.bashrc"           .source = ./config/.bashrc;
            "./.profile"          .source = ./config/.profile;
        };

        #? Shell integrations go here but main bash config is in the system one.
        programs.bash.sessionVariables = {
        };
        programs.bash.shellAliases = {
        };
        
        #? user bash aliases
        programs.bash.shellAliases = {
        };

        #? Extra commands that should be run when initializing an interactive shell.
        # programs.bash.initExtra = ''
        #     ${pkgs.inshellisense}/bin/inshellisense;
        # '';

        # ? Extra commands that should be placed in {file}~/.bashrc.
        # ?   Note that these commands will be run even in non-interactive shells.
        programs.bash.bashrcExtra = ''
        '';

        #? Extra commands that should be run when initializing a login shell.
        programs.bash.profileExtra = ''
        '';
        #? Extra commands that should be run when logging out of an interactive shell.
        programs.bash.logoutExtra = ''
        '';

        # # For LS_COLORS customization options run this in shell:
        # for theme in $(vivid themes); do
        #     echo "Theme: $theme"
        #     LS_COLORS=$(vivid generate $theme)
        #     ls
        #     echo
        # done
    };
}
