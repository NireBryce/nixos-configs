{ 
  lib, 
  pkgs,
  config,
  ... 
}: 

{
  options = {
    wm-kde.enable = lib.mkEnableOption "Enable KDE Window Manager";
  };  
  
  # check for KDE, install KDE packages
  # TODO: figure out what to do with this, they really belong in packages.  Is there a way to make nix disable packages if one isn't installed?
  # look into if you can do mkifs based on system.windowManager.etc or whatever it is
  config = lib.mkIf config.wm-kde.enable {
    home.packages = with pkgs; [    # kde utilities just in case they aren't in nixOS' metapackage
      kdePackages.qttools
      partition-manager
      kcharselect        # symbol picker, may need to be kdePackages.kcharselect
    ];
  };

  
}
