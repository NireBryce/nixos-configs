{
  self, 
  ...
}:


{ 
  # TODO: split this out into where they're installed.
      home.file = {
        "./.bash_logout"      .source = ./.bash_logout;
        "./.bash_profile"     .source = ./.bash_profile;
        "./.bashrc"           .source = ./.bashrc;
        "./.config/F-Sy-H"    .source = ./zsh-f-s-highlight-themes;
        # "./.config/kitty"     .source = ./kitty;
        # "./.config/micro"     .source = ./micro;
        "./.config/sway"      .source = ./sway;
        
        "./.config/zsh"       .source = ./zsh;
        "./.gitconfig"        .source = ./.gitconfig;
        "./.p10k.zsh"         .source = ./zsh-powerlevel10k/.p10k.zsh;
        "./.profile"          .source = ./.profile;
        "./.justfile"         .source = ./.just/.justfile;
        "./.just/.justfile"   .source = ./.just/.justfile;
        "./.just"             .source = ./.just;                          # Fractal subcommands galore.
    };
# TODO: python linkables
}

  # "./.config/zsh/.zshrc".source        = config/zsh/.zshrc;
  # "./.config/steamtinkerlaunch".source = config/steamtinkerlaunch;
  # "./.zshrc".source                    = config/zsh/.zshrc;
  # "./.config/zsh-abbr".source        = config/zsh-abbr;
  # "./.config/zsh-powerlevel10k/.p10k.zsh".source = config/zsh-powerlevel10k/.p10k.zsh;
