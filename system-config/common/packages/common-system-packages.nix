{
    pkgs,
    ...
}:

{
    environment.systemPackages = with pkgs; [ # TODO: describe these
        # Editors
        vim                         # failsafe
        nano                        # backup of a backup, vim is bad on a phone                               https://www.nano-editor.org/
        nanorc                      # nano syntax highlighting                  https://github.com/scopatz/nanorc

        bash                        # bash.  ok i guess.
          #? Bash Plugins
            starship                    # theming
            blesh                       # if bash were zsh
        coreutils                   # coreutils
        curl                        # curl
        gcc                         # gcc
        git                         # git
        micro                       # micro
        stdenv                      # stdenv
        wget                        # wget
        zoxide                      # zoxide
        ripgrep                     # ripgrep
        mullvad-vpn                 # mullvad-vpn
        linuxHeaders                # linux headers
        tailscale                   # TODO: move to module

        # Archive and compression
        zip                           # zip                                       http://www.info-zip.org/
        unzip                         # unzip                                     http://www.info-zip.org/
        p7zip                         # p7zip                                     https://github.com/p7zip-project/p7zip
        
        # build tools
        gnumake                       # gnumake                                   https://github.com/ogham/gnumake
    ];
}
