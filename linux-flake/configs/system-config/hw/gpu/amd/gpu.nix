{
    pkgs,
    lib,
    nixos-hardware,
    ...
}:

{
    imports = [ 
      nixos-hardware.nixosModules.common-gpu-amd 
    ];
        
    environment.systemPackages = with pkgs; [ 
        mesa                        # todo: document
        glfw                        # todo: document
        dxvk                        # todo: document
        vulkan-tools                # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
        glxinfo                     # glxinfo                                   https://www.khronos.org/opengl/
        
        clinfo                      # clinfo                                    https://github.com/Oblomov/clinfo
        
        amf-headers                 # todo: document
        amdgpu_top                  # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
    ];

# general
    # mesa / vulkan
    hardware.graphics.enable        = lib.mkDefault true;  
    hardware.graphics.enable32Bit   = true;
    hardware.graphics.extraPackages = with pkgs; [
        libva-utils
        rocmPackages.clr.icd # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-amd
    ];

    
# AMD
    # AMD vulkan drivers
    hardware.amdgpu.amdvlk.enable   = true;   # disable this to default to RadV
    hardware.amdgpu.amdvlk.support32Bit.enable = true;
}
