{ 
  ...
}:

{
  imports = [ 
    ./_hm.zsh.nix 
  ];

  

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
    STARSHIP_CONFIG="$HOME/.config/starship.toml";
    STARSHIP_CACHE="$HOME/.cache/starship";
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
  

}

