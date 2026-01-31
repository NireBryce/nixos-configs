{
    lib,
    config,
    ...
}:
let
    enabled = builtins.elem "wmJovian" (config.my.roles or []);
    
in
{
    flake.modules.nixos.wm.jovian = { config, pkgs, ... }: {
        config = lib.mkIf enabled {
            boot.loader = {
                # todo: replace after switching tinylaptop to limine
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
        };
    };
}

# more examples:
# https://github.com/gradientvera/GradientOS/blob/adcc4892703dc2129fc8f16d0bce56c2146cd788/mixins/jovian-decky-loader.nix#L5
# https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
