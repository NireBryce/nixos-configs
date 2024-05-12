{ pkgs, ... }: {
  home.packages = with pkgs; [
# kde utilities just in case they aren't in nixOS' metapackage
    qt6.qttools
    partition-manager
    kcharselect        # symbol picker, may need to be kdePackages.kcharselect
    
  ];
  
}
