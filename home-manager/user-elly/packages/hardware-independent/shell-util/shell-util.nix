{ 
    pkgs,
    ...
}:
let
    bashPkgs = with pkgs; [
        # inshellisense                 # intellisense type shell complete          https://github.com/microsoft/inshellisense
        blesh                         # zsh line editor tricks for bash           https://github.com/akinomyoga/ble.sh
        bash-completion               # bash complete                             https://github.com/scop/bash-completion
    ];
    multiplexerPkgs = with pkgs; [
        zellij                        # terminal multiplexer/tiler rich TUI       https://zellij.dev/
        tmux                          # terminal multiplexer                      https://github.com/tmux/tmux
    ];
    textPkgs = with pkgs; [
        bat                           # `cat`, `less` alternative (w/ SynHi)      https://github.com/sharkdp/bat
        moar                          # better pager for some things              https://github.com/walles/moar
        glow                          # terminal markdown viewer                  https://github.com/charmbracelet/glow
    ];
    statsPkgs = with pkgs; [
        btop                          # `htop` alternative                        https://github.com/aristocratos/btop
        hyfetch                       # neofetch replacement                      https://github.com/hykilpikonna/HyFetch
    ];
    storageStats = with pkgs; [
        du-dust                       # `du` alternative                          https://github.com/bootandy/dust
        duf                           # `df` alternative                          https://github.com/muesli/duf
    ];
    textManipPkgs = with pkgs; [
        jc                            # jc converts output into JSON or YAML      https://github.com/kellyjonbrazil/jc
        jq                            # jq                                        https://github.com/stedolan/jq
        yq-go                         # yaml jq                                   https://github.com/mikefarah/yq
    ];
    navPkgs = with pkgs; [
        eza                           # `ls`, `tree` alternative                  https://github.com/ogham/eza
        zoxide                        # smarter cd                                https://github.com/ajeetdsouza/zoxide
        broot                         # `br` - tree alternative                   https://github.com/Canop/broot
        tree                          # necessary for some `zi` things            https://oldmanprogrammer.net/source.php?dir=projects/tree
    ];
    fileBrowsers = with pkgs; [
        mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
    ];
    searchPkgs = with pkgs; [
        fd                            # `find` alternative                        https://github.com/sharkdp/fd
        fzf                           # fuzzy finder and fast TUI via piping      https://github.com/junegunn/fzf
        ripgrep                       # `rg` very fast grep replacement           https://github.com/BurntSushi/ripgrep
    ];
    infoPkgs = with pkgs; [
        which                         # `which`                                   https://www.gnu.org/software/which/
        file                          # `file` show filetype                      https://darwinsys.com/file
    ];
    utilityShells = with pkgs; [
        nushell                       # nushell -c for tabular display any shell  https://github.com/nushell/nushell
    ];
    shellCustomization = with pkgs; [
        vivid                         # LS_COLORS generator                       https://github.com/sharkdp/vivid
        starship                      # shell prompt generator                    https://github.com/starship/starship
    ];

in {
    home.packages = [
        bashPkgs
        multiplexerPkgs
        textPkgs
        statsPkgs
        storageStats
        textManipPkgs
        navPkgs
        fileBrowsers
        searchPkgs
        infoPkgs
        utilityShells
        shellCustomization 
    ];
}
