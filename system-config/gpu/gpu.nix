{
    pkgs,
    ...
}:

{

    environment.systemPackages = with pkgs; [ 
        mesa                        # todo: document
        glfw                        # todo: document
        dxvk                        # todo: document
        vulkan-tools                # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
        glxinfo                     # glxinfo                                   https://www.khronos.org/opengl/
        
        # maybe amd only
        clinfo                      # clinfo                                    https://github.com/Oblomov/clinfo
        
        # amd
        amf-headers                 # todo: document
        amdgpu_top                  # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
    ];

# general
    # mesa / vulkan
    hardware.graphics.enable = lib.mkDefault true;  
    hardware.graphics.enable32Bit = true;           #     
    hardware.graphics.extraPackages = with pkgs; [  #     
      pipewire
      libva-utils
    ];
    
# AMD
    # AMD vulkan drivers
    hardware.amdgpu.amdvlk.enable = true;   # disable this to default to RadV
}
