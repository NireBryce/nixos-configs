# modules/options.nix
#
# This flake-parts module defines custom options that describe machine characteristics.
# Other modules can read these options to make decisions.

{ lib, ... }:

{
  # We're adding options to the flake-level config, not to NixOS or home-manager.
  # This is a flake-parts option that will be available everywhere.
  options.my = {
    
    # Which machine are we building for?
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the machine being configured";
    };
    
    # Machine capability flags - these describe WHAT the machine can do,
    # not WHICH machine it is. This is more flexible.
    capabilities = {
      
       isBattery = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this machine has a battery";
      };
      isHandheld = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is a handheld machine";
      };
    
      isGaming = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this machine is used for gaming";
      };

      isDarwin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this machine is running macOS";
      };
      
       isMinimal = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this machine is pared down";
      };
    };
  };
}
