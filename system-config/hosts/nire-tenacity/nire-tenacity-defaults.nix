{
    self,
    ...
}:
let
_flakeDir           = self;
_systemConfigDir    = "${_flakeDir}/system-config";

_hostName           = "nire-tenacity";
_cpuVendor          = "amd";
_gpuVendor          = "amd";
in
{
    system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion

    imports = [
        "${_systemConfigDir}/hosts/${_hostName}/hw-conf"
        "${_systemConfigDir}/hosts/${_hostName}/fixes"
        "${_systemConfigDir}/hw/gpu/${_gpuVendor}"
        "${_systemConfigDir}/hw/cpu/${_cpuVendor}"
        "${_systemConfigDir}/peripherals/zsa-moonlander.nix"
        "${_systemConfigDir}/peripherals/logitech-g600.nix"
        "${_systemConfigDir}/common"
        "${_systemConfigDir}/gaming"
        "${_flakeDir}/___modules/linux-crisis-utilities.nix"

        # impermanence
        # ____________________________________________________ 
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        # ----------------------------------------------------
        "${_systemConfigDir}/impermanence/_WARN.impermanence.nix"
    ];

    #? This determines what to add to /run/current-system/sw, generally defined elsewhere
    environment.pathsToLink = [

    ];
}
