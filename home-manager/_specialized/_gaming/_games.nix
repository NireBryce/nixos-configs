{ pkgs, misc, ... }: {
  home.packages = with pkgs; [
    # game launchers
    lutris

  # proton
    protonup-qt               # proton installer/updater
    protontricks
  
  # wine
    wineWowPackages.waylandFull

    # logitech mouse config
    piper                     # logitech mouse manager https://github.com/soxoj/piper
  ];
}
