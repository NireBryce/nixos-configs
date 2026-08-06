{ config, inputs, ... }:
{
    flake.modules.nixos.handheld.imports = [ config.flake.modules.nixos.wm-jovian ];

    flake.modules.nixos.wm-jovian =
{ config, pkgs, lib, ... }: 
{
    imports = [ inputs.jovian.nixosModules.default ];
    boot.loader = {
        # todo: hack, replace after switching tinylaptop to limine
        limine.enable               = lib.mkForce false;
        limine.secureBoot.enable    = lib.mkForce false;
        systemd-boot.enable         = lib.mkDefault true;
    };
    systemd.services.decky-loader.environment.LD_LIBRARY_PATH = lib.makeLibraryPath config.jovian.decky-loader.extraPackages;
    services.desktopManager.plasma6.enable = true;
    
    jovian = {
        steam = {
            enable              = true;
            autoStart           = true;
            desktopSession      = "plasma";
            user                = "elly";
        };
        hardware.has.amd.gpu    = true;

        decky-loader = {
            enable              = true;
            extraPackages =  with pkgs; [
                # power-profiles-daemon
                inotify-tools
                libpulseaudio
                coreutils
                gamescope
                gamemode
                mangohud
                pciutils
                systemd
                gnugrep
                python3
                gnused
                procps
                steam
                gawk
                file
            ];
            extraPythonPackages = pythonPkgs: with pythonPkgs; [
                click
            ];
        };
    };

    # `adjustor` was removed from nixpkgs; it now ships as part of the
    # handheld-daemon package and is pulled in by the adjustor option below.

    # needed for tdp adjustor
    boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

    services.handheld-daemon = {
    # TODO: if you're coming here from github search looking for ways to make HHD work,
    #     I need you to understand that the TDP control is currently mired in nixpkgs
    #     if you want it to work, it needs some work that I cannot do.
    #     https://github.com/NixOS/nixpkgs/pull/347279
        enable      = true;
        user        = "elly"; # TODO: use flake-parts to make this declared centrally
        ui.enable   = true;
        adjustor = {
            enable = true;
            loadAcpiCallModule = true;
        };

    };

    systemd.services."power-profiles-daemon" = {
        enable = false; # conflicts with adjustor in hhd
    };
}
;}

# more examples:
# https://github.com/gradientvera/GradientOS/blob/adcc4892703dc2129fc8f16d0bce56c2146cd788/mixins/jovian-decky-loader.nix#L5
# https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
