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
    vulkan-tools                # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
    glxinfo                     # glxinfo                                   https://www.khronos.org/opengl/
    clinfo                      # clinfo                                    https://github.com/Oblomov/clinfo
    amdgpu_top                  # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
  ];
  hardware.opengl.extraPackages = with pkgs; [
    libva-utils
  ];
  
}
