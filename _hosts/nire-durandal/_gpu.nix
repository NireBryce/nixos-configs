{ 
  pkgs, 
  ... 
}: 
{  
  environment.systemPackages = with pkgs; [ # TODO: describe these
    amf-headers
    mesa
    glfw
    dxvk
  ];
  hardware.opengl.extraPackages = with pkgs; [
    libva-utils
  ];
  
}
