{ pkgs, lib, config, ... }: {
  options = {
    _hm-kde.enable = lib.mkEnableOption "Enables KDE packages";
  };
  config = lib.mkIf config._hm-kde.enable {
    home.packages = with pkgs; [

  # kde utilities just in case they aren't in nixOS' metapackage
      qt6.qttools
      partition-manager
      kcharselect        # symbol picker, may need to be kdePackages.kcharselect
      
    ];
  };
}
