{
    pkgs,
    ...
}:
{
    imports = [
        ../common/font
        ../common/networking
        ../common/nix
    ];
    environment.systemPackages = with pkgs; [
      # bash
        shellcheck
        shfmt
        bash-completion
        
      # git
        git
        gh
        diffutils
        delta
        riffdiff
        lazygit
        commitizen
        
      # utils
        tldr                    # man but gets to the point first
        curl
        wget
        zip unzip
        bat                     # cat and less alternative, syntax highlighting
        broot                   # br - tree alternative
        du-dust                 # du alternative
        duf                     # df alternative
        eza
        fd
        file                    # show filetype
        fzf
        ripgrep
        zellij
        magic-wormhole-rs       # file transfer
        
      # nix
        deadnix                 # scan for dead nix code
        manix   # nix mman
        nix-du  # nix store analysis
        nix-tree    # dependency graph
        nix-diff  # diff nix code
        nvd     # nix version diff
        nixfmt
        statix  # antipattern linter
        nil

      # system tools              # system tools                              # System Tools
        wl-clipboard                  # clipboard in wayland                      https://github.com/bugaevc/wl-clipboard
        wl-clipboard-x11              # clipboard in xwayland                     https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=wl-clipboard

      # GUI
        bitwarden                     # password manager                          https://bitwarden.com/

      # editora
        neovim
        nanorc
        micro

    ];
}
