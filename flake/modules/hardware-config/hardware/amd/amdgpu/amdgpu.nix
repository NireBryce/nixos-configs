# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ inputs, ... }:
{
    nixos = { pkgs, ... }: {
        imports = [ inputs.nixos-hardware.nixosModules.common-gpu-amd ];

        environment.systemPackages = with pkgs; [
            mesa # todo: document
            glfw # todo: document
            dxvk # todo: document
            vulkan-tools # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
            mesa-demos # glxinfo   -> mesa-demos                                 https://www.khronos.org/opengl/

            clinfo # clinfo                                    https://github.com/Oblomov/clinfo

            amf-headers # todo: document
            amdgpu_top # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
        ];

        # mesa / vulkan
        # This is also what gives sunshine.nix's VAAPI hardware encode a driver to
        # find -- mesa's radeonsi bundles VAAPI for AMD, no extra package needed the
        # way Intel's does. See that file for the rest of the story (why the encoder
        # isn't forced) and sunshine-elly.nix for the device-permission groups it needs.
        hardware.graphics = {
            enable = true;
            enable32Bit = true;
            extraPackages = with pkgs; [
                libva-utils
                rocmPackages.clr.icd # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-amd
            ];
        };
    };
}
