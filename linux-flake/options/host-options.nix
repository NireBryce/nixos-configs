# modules/options.nix
#
# This flake-parts module defines custom options that describe machine characteristics.
# Other modules can read these options to make decisions.

{ lib, ... }:

{
  # We're adding options to the flake-level config, not to NixOS or home-manager.
  # This is a flake-parts option that will be available everywhere.
    options.my.roles = {
        amdCpu = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "amd cpu configuration";
        };
        amdGpu = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "amd cpu configuration";
        };
        intelCpu = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "intel cpu configuration";
        };
        gaming = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable gaming-related packages and configuration";
        };
        battery = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable battery-related packages and configuration";
        };
        handheld = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable handheld-related packages and configuration";
        };
        darwin = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable mac-related packages and configuration";
        };
        notMinimal = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable fancy packages and configuration";
        };
        develop = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable development packages and configuration";
        };
        wmKde = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable KDE window manager packages and config";
        };
        wmWayland = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable wayland packages and config";
        };
        wmJovian = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Jovian-nix";
        };
        
        impermanent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable impermanence";
        };
        user-elly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "set elly user";
        };
    
    };
}
