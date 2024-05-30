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
  config = lib.mkIf config.wm-kde.enable {
    home.packages = with pkgs; [    # kde utilities just in case they aren't in nixOS' metapackage
      kdePackages.qttools
      partition-manager
      kcharselect        # symbol picker, may need to be kdePackages.kcharselect
    ];
  };

  
}
