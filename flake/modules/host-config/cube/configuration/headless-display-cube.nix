# Gives cube a desktop for Sunshine (general-config/system/gaming/sunshine.nix)
# to stream with no monitor attached; added 2026-10-06. Two parts, both
# needed:
#
# - A display. Sunshine captures over KMS, which needs an active output, and
#   with nothing plugged in every connector on card1 reads `disconnected`.
#   HDMI-A-1 is forced on (`video=HDMI-A-1:e`, which amdgpu needs to skip its
#   own connection check) and fed an EDID generated from a modeline
#   (`drm.edid_firmware=HDMI-A-1:edid/cube1080p60.bin`). nixpkgs'
#   nixos/modules/services/hardware/display.md documents both. A monitor
#   plugged into HDMI-A-1 gets this forced mode, not its own EDID; use the
#   USB4 or other ports for a real screen.
#   `amdgpu.virtual_display` was the alternative and was rejected: when it is
#   set, amdgpu_discovery.c adds only the virtual display block and skips DC,
#   so every physical port goes dark.
# - A session. Sunshine is a user service wanted by graphical-session.target,
#   so it only runs once someone is logged into Plasma. Autologin starts that
#   session at boot. stream-lock-cube.nix locks it straight away, so the
#   console and Moonlight both land on the lock screen.
#
# The modeline is CEA-861 VIC 16, 1920x1080@60 (148.5 MHz). Names are
# capped at 12 characters by the module.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "cube: forced HDMI-A-1 with a 1080p60 EDID, plus Plasma autologin, so Sunshine streams headless";
            hardware.display = {
                edid.modelines."cube1080p60" = "148.50  1920 2008 2052 2200  1080 1084 1089 1125  +hsync +vsync";
                outputs."HDMI-A-1"           = { edid = "cube1080p60.bin"; mode = "e"; };
            };

            services.displayManager.autoLogin = {
                enable = true;
                user   = "elly";
            };
        };
}
