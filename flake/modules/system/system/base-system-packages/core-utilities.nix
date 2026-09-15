{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                coreutils # coreutils
                curl # curl
                gcc # gcc
                git # git
                stdenv # stdenv
                wget # wget
                ripgrep # ripgrep
                linuxHeaders # linux headers

                # Archive and compression
                zip # zip                                       http://www.info-zip.org/
                unzip # unzip                                     http://www.info-zip.org/
                p7zip # p7zip                                     https://github.com/p7zip-project/p7zip

                # build tools
                gnumake # gnumake
            ];
        };
}
