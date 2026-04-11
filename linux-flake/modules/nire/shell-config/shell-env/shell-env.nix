{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.shell-config._.${moduleName}.homeManager = {
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
        };  
        home.sessionVariables = { 
            EDITOR                  = "micro";
            MICRO_TRUECOLOR         = 1;
            NIXPKGS_ALLOW_UNFREE    = 1;
            PYTHONBREAKPOINT        = "ipdb.set_trace";
            COLORTERM               = "truecolor";
            PAGER                   = "less -R";
            MANPAGER                = "${pkgs.bat}/bin/bat --language man";
            LC_CTYPE                = "en_US.UTF-8";
            LS_COLORS               = "$(${pkgs.vivid}/bin/vivid generate dracula)";  # https://github.com/sharkdp/vivid
            EZA_COLORS              = "$(${pkgs.vivid}/bin/vivid generate dracula)";
            # STARSHIP_CONFIG         = "$HOME/.config/starship.toml";
            # STARSHIP_CACHE          = "$HOME/.cache/starship";
            PYTHON                  = "PYTHON";
        };
        home.sessionPath = [ 
            "/usr/local"
            "/usr/bin"
            "$HOME/bin"
            "$HOME/.local/bin"
            "$HOME/.nix-profile/bin"
            "$HOME/.zi/bin"
            "$HOME/.config/zi/bin"
            "$HOME/.cargo/bin"
        ];
    };
}
