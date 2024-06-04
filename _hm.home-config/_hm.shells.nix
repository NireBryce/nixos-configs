{ 
  ...
}:

{
  imports = [ 
    ./_hm.zsh.nix 
  ];

  home.shellAliases = { 
    # for functions in aliases:  https://stackoverflow.com/questions/34340575/zsh-alias-with-parameter
    lcd = ''f() { cd $1 && ls -lah };f'';               
    manix-browse = ''manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --preview="manix '{}'" | xargs manix'';
    ll           ="ls -l";
    cp           ="cp -i";                              # Confirm before overwriting something
    cd           = "x";                                 # Empty oneletter for zoxide to not interfere with zi
    exa          = "eza --icons=always";                # back compat tools
    ls           = "eza --icons=always --header --group-directories-first --hyperlink";
    gsa="git stash push";
    img-cat="kitty +kitten icat";
    kssh="kitty +kitten ssh";
  };  

  home.sessionVariables = { 
    EDITOR = "micro";
    MICRO_TRUECOLOR = 1;
    NIXPKGS_ALLOW_UNFREE = 1;
    PYTHONBREAKPOINT = "ipdb.set_trace";
    COLORTERM="truecolor";
    PAGER="less -R";
    MANPAGER="bat --language man";
    LC_CTYPE="en_US.UTF-8";
    LS_COLORS="$(vivid generate dracula)";                                      # https://github.com/sharkdp/vivid
    EZA_COLORS="$(vivid generate dracula)";
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
  programs.zsh.zsh-abbr.abbreviations = {
    # ! WARN: unsure how globals work here
    # for now they're declared in the zsh config
    # but that's not declarative -- it saves them to abbr
    # even if you remove them from the zsh config
    "abbr remove"="abbr erase";
    "abbr rm"="abbr erase";
    "cs-zsh-bindings"="bindkey";
    "highlighting-theme-default"="fast-theme sv-orple";
    "wh"="wormhole";
    "whence"="type -a";
    "zsh-keymap"="bindkey";
    "rebuild-system" = "nh os switch .";
    "rebuild-home" = "nh home switch ."; 
  };

}

