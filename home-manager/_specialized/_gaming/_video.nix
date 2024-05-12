{ pkgs, misc, ... }: {
  home.packages = [
  # graphics  
    pkgs.glfw
    pkgs.dxvk
  ];
}
