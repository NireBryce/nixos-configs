{ pkgs, misc, ... }: {
  # TODO: lib.mkIf lib.mkEnable video
  home.packages = [
  # graphics  
    pkgs.glfw
    pkgs.dxvk
  ];
}
