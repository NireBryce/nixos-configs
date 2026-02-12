{
    ...
}:
{ den.aspects.nixos.provides.hw-amd-gpu = 
{ nixos-hardware, pkgs, ... }: 
{
    imports = [ nixos-hardware.nixosModules.common-gpu-amd ];
        
    environment.systemPackages = with pkgs; [ 
        mesa                        # todo: document
        glfw                        # todo: document
        dxvk                        # todo: document
        vulkan-tools                # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
        mesa-demos                  # glxinfo   -> mesa-demos                                 https://www.khronos.org/opengl/
        
        clinfo                      # clinfo                                    https://github.com/Oblomov/clinfo
        
        amf-headers                 # todo: document
        amdgpu_top                  # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
    ];

    # mesa / vulkan
    hardware.graphics.enable        = true;  
    hardware.graphics.enable32Bit   = true;
    hardware.graphics.extraPackages = with pkgs; [
        libva-utils
        rocmPackages.clr.icd # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-amd
    ];

}
;}
