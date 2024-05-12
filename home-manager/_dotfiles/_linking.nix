{...}:

{ # TODO: split this out into where they're installed.
  # TODO: mkEnable, mkIf, for the things that need to be toggled,  less important here because who cares about hanging dotfiles in .config though.
  home.file = {
  "./.bash_logout".source              = config/.bash_logout;
  "./.bash_profile".source             = config/.bash_profile;
  "./.bashrc".source                   = config/.bashrc;
  "./.config/atuin".source             = config/atuin;
  "./.config/F-Sy-H".source            = config/zsh-f-s-highlight-themes;
  "./.config/kitty".source             = config/kitty;
  "./.config/micro".source             = config/micro;
  "./.config/steamtinkerlaunch".source = config/steamtinkerlaunch;
  "./.config/sway".source              = config/sway;
  "./.config/zellij".source            = config/zellij;
  "./.config/zsh".source               = config/zsh;
  "./.config/zsh/.zshrc".source        = config/zsh/.zshrc;
  "./.gitconfig".source                = config/.gitconfig;
  "./.p10k.zsh".source                 = config/zsh-powerlevel10k/.p10k.zsh;
  "./.profile".source                  = config/.profile;
  "./.talon".source                    = config/.talon;
  "./.zlogin".source                   = config/zsh/.zlogin;
  "./.zlogout".source                  = config/zsh/.zlogout;
  "./.zprofile".source                 = config/zsh/.zprofile;
  "./.zshenv".source                   = config/zsh/.zshenv;
  "./.zshrc".source                    = config/zsh/.zshrc;
  # "./.config/zsh-abbr".source        = config/zsh-abbr;
  # "./.config/zsh-powerlevel10k/.p10k.zsh".source = config/zsh-powerlevel10k/.p10k.zsh;
  };
# TODO: python linkables
}
