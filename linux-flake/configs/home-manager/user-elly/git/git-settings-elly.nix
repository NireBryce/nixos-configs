{ den.aspects.hm.provides.git = 
{ ... }:
{
    home.file."./.gitconfig".source = ./.gitconfig;
    
    programs.git = {        # User-specific git config
        enable = true;
        settings = {
            alias = {
                pushall = "!git remote | xargs -L1 git push --all";
                graph = "log --decorate --oneline --graph";
                add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
            };
            user = {
                name = "Nire Bryce";
                email = "nire@computernope.net";
            };
            
            feature.manyFiles = true;
            init.defaultBranch = "main";
            gpg.format = "ssh";
        };
        signing = {
            key = "~/.ssh/id_ed25519";
            signByDefault = builtins.stringLength "~/.ssh/id_ed25519" > 0;
        };

        lfs.enable = true;
        ignores = [ ".direnv" "result" ];
    };
};

}#
