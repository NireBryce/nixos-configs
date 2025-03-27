{ 
  pkgs,
  ... 
}:

{
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

    home.shellAliases = { 
      # for in-place functions in aliases refer to:  https://stackoverflow.com/questions/34340575/zsh-alias-with-parameter
        lcd             = ''f() { cd $1 && ls -lah };f'';               
        cdls            = ''f() { cd $1 && ls -lah };f'';               
        manix-browse    = ''${pkgs.manix}/bin/manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --preview="${pkgs.manix}/bin/manix '{}'" | xargs manix'';
        ll              = "ls -l";
        cp              = "cp -i";    # Confirm before overwriting something
        cd              = "x";        # Empty oneletter for zoxide to not interfere with zi
        exa             = "${pkgs.eza}/bin/eza --icons=always"; # exa back compat for tools
        ls              = "${pkgs.eza}/bin/eza --icons=always --header --group-directories-first --hyperlink";
        gsa             = "${pkgs.git}/bin/git stash push";
        img-cat         = "${pkgs.kitty}/bin/kitty +kitten icat";
        kssh            = "${pkgs.kitty}/bin/kitty +kitten ssh";
    };  

  # ! WARN: unsure how global aliases work here
  # for now they're declared in the zsh config but that's 
  #    not declarative -- it saves them to abbr even if
  #    you remove them from the zsh config
    programs.zsh.zsh-abbr.abbreviations = {
        "abbr remove"                = "abbr erase";
        "abbr rm"                    = "abbr erase";
        "cs-zsh-bindings"            = "bindkey";
        "highlighting-theme-default" = "fast-theme sv-orple";
        "wh"                         = "wormhole";
        "whence"                     = "type -a";
        "zsh-keymap"                 = "bindkey";
        "rebuild-system"             = "nh os switch .";
        "rebuild-home"               = "nh home switch ."; 
    };

    home.sessionVariables = { 
        EDITOR = "micro";
        MICRO_TRUECOLOR = 1;
        NIXPKGS_ALLOW_UNFREE = 1;
        PYTHONBREAKPOINT = "ipdb.set_trace";
        COLORTERM="truecolor";
        PAGER="less -R";
        MANPAGER="${pkgs.bat}/bin/bat --language man";
        LC_CTYPE="en_US.UTF-8";
        LS_COLORS="$(${pkgs.vivid}/bin/vivid generate dracula)";  # https://github.com/sharkdp/vivid
        EZA_COLORS="$(${pkgs.vivid}/bin/vivid generate dracula)";
        STARSHIP_CONFIG="$HOME/.config/starship.toml";
        STARSHIP_CACHE="$HOME/.cache/starship";
  };
}
