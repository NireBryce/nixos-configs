# desc = "";
{ pkgs, ... }:
{
    home.shellAliases = { 
        # for in-place functions in aliases refer to:  https://stackoverflow.com/questions/34340575/zsh-alias-with-parameter
        lcd             = ''f() { cd $1 && ls -lah };f'';               
        cdls            = ''f() { cd $1 && ls -lah };f'';               
        manix-browse    = ''${pkgs.manix}/bin/manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --preview="${pkgs.manix}/bin/manix '{}'" | xargs manix'';
        ll              = "ls -l";
        cp              = "cp -i";    # Confirm before overwriting something
        cd              = "x";        # Empty oneletter for zoxide to not interfere with zi
        exa             = "${pkgs.eza}/bin/eza --icons=always"; # exa back compat for tools
        # ls              = "${pkgs.eza}/bin/eza --icons=always --header --group-directories-first --hyperlink";
        # gsa             = "${pkgs.git}/bin/git stash push";
        img-cat         = "${pkgs.kitty}/bin/kitty +kitten icat";
        kssh            = "${pkgs.kitty}/bin/kitty +kitten ssh";
    };  
}
