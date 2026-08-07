{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.elly-aliases ];

    flake.modules.homeManager.elly-aliases = 
{ pkgs, ... }:
{
    home.shellAliases = { 
        # for in-place functions in aliases refer to:  https://stackoverflow.com/questions/34340575/zsh-alias-with-parameter
        lcd             = ''f() { cd $1 && ls -lah };f'';               
        cdls            = ''f() { cd $1 && ls -lah };f'';               
        ll              = "ls -l";
        cp              = "cp -i";    # Confirm before overwriting something
        exa             = "${pkgs.eza}/bin/eza --icons=always"; # exa back compat for tools
        # ls              = "${pkgs.eza}/bin/eza --icons=always --header --group-directories-first --hyperlink";
        # gsa             = "${pkgs.git}/bin/git stash push";
        img-cat         = "${pkgs.kitty}/bin/kitty +kitten icat";
        kssh            = "${pkgs.kitty}/bin/kitty +kitten ssh";
        # Moved out of shell-zsh/zsh.nix, where it was the only alias still
        # doing anything. NOTE: this path is stale -- the rust dev-shell lives
        # at misc/dev-shells/rust, and the checkout is nixos-configs, not
        # nixos. Left as-is rather than guessed at; fix to match your checkout.
        rustdevshell    = "nix develop ~/nixos/dev-shells/rust#";
    };  
}
;}
