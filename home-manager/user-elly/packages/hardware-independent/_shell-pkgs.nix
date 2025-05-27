{ 
    pkgs,
    ...
}:

{
    home.packages = with pkgs; [
      # bash                      # bash                                      # bash
        # inshellisense                 # intellisense type shell complete          https://github.com/microsoft/inshellisense
        blesh                         # zsh line editor tricks for bash           https://github.com/akinomyoga/ble.sh
  
        # atuin                         # shared encrypted shell history            https://github.com/ellie/atuin
        bash-completion               # bash complete                             https://github.com/scop/bash-completion
        bat                           # `cat`, `less` alternative (w/ SynHi)      https://github.com/sharkdp/bat
        broot                         # `br` - tree alternative                   https://github.com/Canop/broot
        btop                          # `htop` alternative                        https://github.com/aristocratos/btop
        du-dust                       # `du` alternative                          https://github.com/bootandy/dust
        duf                           # `df` alternative                          https://github.com/muesli/duf
        eza                           # `ls`, `tree` alternative                  https://github.com/ogham/eza
        fd                            # `find` alternative                        https://github.com/sharkdp/fd
        file                          # `file` show filetype                      https://darwinsys.com/file
        fzf                           # fuzzy finder and fast TUI via piping      https://github.com/junegunn/fzf
        glow                          # terminal markdown viewer                  https://github.com/charmbracelet/glow
        hyfetch                       # neofetch replacement                      https://github.com/hykilpikonna/HyFetch
        jc                            # jc converts output into JSON or YAML      https://github.com/kellyjonbrazil/jc
        jq                            # jq                                        https://github.com/stedolan/jq
        mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
        moar                          # better pager for some things              https://github.com/walles/moar
        nushell                       # nushell -c for tabular display any shell  https://github.com/nushell/nushell
        ripgrep                       # `rg` very fast grep replacement           https://github.com/BurntSushi/ripgrep
        tree                          # necessary for some `zi` things            https://oldmanprogrammer.net/source.php?dir=projects/tree
        starship                      # shell prompt generator                    https://github.com/starship/starship
        vivid                         # LS_COLORS generator                       https://github.com/sharkdp/vivid
        which                         # `which`                                   https://www.gnu.org/software/which/
        yq-go                         # yaml jq                                   https://github.com/mikefarah/yq
        zellij                        # terminal multiplexer/tiler rich TUI       https://zellij.dev/
        tmux                          # terminal multiplexer                      https://github.com/tmux/tmux
        zoxide                        # smarter cd                                https://github.com/ajeetdsouza/zoxide
    ];
}
