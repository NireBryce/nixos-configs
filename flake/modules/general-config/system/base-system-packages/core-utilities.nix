# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
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
