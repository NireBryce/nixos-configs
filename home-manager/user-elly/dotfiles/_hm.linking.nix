{
  self, 
  ...
}:


{ 
  # TODO: split this out into where they're installed.
  # TODO: mkEnable, mkIf, for the things that need to be toggled,  less important here because who cares about hanging dotfiles in .config though.
    home.file = {
        "./.bash_logout"      .source = config/.bash_logout;
        "./.bash_profile"     .source = config/.bash_profile;
        "./.bashrc"           .source = config/.bashrc;
        "./.config/atuin"     .source = config/atuin;
        "./.config/F-Sy-H"    .source = config/zsh-f-s-highlight-themes;
        "./.config/kitty"     .source = config/kitty;
        "./.config/micro"     .source = config/micro;
        "./.config/sway"      .source = config/sway;
        "./.config/zellij"    .source = config/zellij;
        "./.config/zsh"       .source = config/zsh;
        "./.gitconfig"        .source = config/.gitconfig;
        "./.p10k.zsh"         .source = config/zsh-powerlevel10k/.p10k.zsh;
        "./.profile"          .source = config/.profile;
        "./.zlogin"           .source = config/zsh/.zlogin;
        "./.zlogout"          .source = config/zsh/.zlogout;
        "./.zprofile"         .source = config/zsh/.zprofile;
        "./.zshenv"           .source = config/zsh/.zshenv;
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
