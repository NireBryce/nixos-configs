# The handheld half of the desktop story: Jovian, Steam, and the TDP stack.
#
# Generic to handhelds -- machines with built-in controllers that occasionally
# launch a SteamOS session -- not specific to tenacity; a second handheld would
# import this too.
#
# The Plasma 6 desktop this drops back to lives in kde-base.nix, imported below.
# It used to be one `services.desktopManager.plasma6.enable = true` here, which
# gave the handheld a desktop session with no XWayland and none of the KDE
# applications; kde-base.nix's history block has the detail.
#
# Not moved to kde-base: sddm, the default session and autologin all come from
# Jovian's own modules/steam/autostart.nix, which sets defaultSession to
# "gamescope-wayland". That is the half of kde-desktop.nix this host must not
# have.
{ config, lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Bound out here, before the module body: inside it `config` is the
        # NixOS config and `config.flake.modules...` would not resolve. The body
        # below genuinely needs the inner one, for
        # `config.jovian.decky-loader.extraPackages`, so the two must not be
        # confused. See CLAUDE.md, "There are two different `config`s".
        kdeBase = config.flake.modules.nixos.kde-base;
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }: {
            # # description = "Jovian/SteamOS handheld: Steam session, decky, TDP control";
            imports = [
                inputs.jovian.nixosModules.default # I think this is instead of needing them as module args?
                kdeBase
            ];

            # `config.jovian.…`, not `inputs.jovian.…`: the Jovian flake exposes
            # only nixosModules/legacyPackages/overlays/checks/devShells, no
            # `decky-loader`. The intended referent is the module option this
            # same file sets below.
            systemd.services.decky-loader.environment.LD_LIBRARY_PATH =
              lib.makeLibraryPath
              config.jovian.decky-loader.extraPackages;

            jovian = {
                steam = {
                    enable = true;
                    autoStart = true;
                    desktopSession = "plasma";
                    user = "elly";
                };
                hardware.has.amd.gpu = true;

                decky-loader = {
                    enable = true;
                    extraPackages = with pkgs; [
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
            # `adjustor` was removed from nixpkgs and folded into
            # handheld-daemon; referencing it fails evaluation outright. The
            # services.handheld-daemon.adjustor option set below already pulls
            # it in, so nothing needs to be listed here.

            # needed for tdp adjustor
            boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

            services.handheld-daemon = {
                # TODO: if you're coming here from github search looking for ways to make HHD work,
                #     I need you to understand that the TDP control is currently mired in nixpkgs
                #     if you want it to work, it needs some work that I cannot do.
                #     https://github.com/NixOS/nixpkgs/pull/347279
                enable = true;
                user = "elly"; # TODO: use flake-parts to make this declared centrally
                ui.enable = true;
                adjustor = {
                    enable = true;
                    loadAcpiCallModule = true;
                };
            };
            
            systemd.services."power-profiles-daemon" = {
                enable = false; # conflicts with adjustor in hhd
            };
        };
}

# more examples:
# https://github.com/gradientvera/GradientOS/blob/adcc4892703dc2129fc8f16d0bce56c2146cd788/mixins/jovian-decky-loader.nix#L5
# https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
