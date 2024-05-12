{ pkgs, misc, ... }: {
  home.packages = with pkgs; [
    # pipewire
    wireplumber

  ];
}
