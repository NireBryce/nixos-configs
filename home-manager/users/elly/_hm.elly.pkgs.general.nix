{ pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{

# TODO: make server config




  home.packages = with pkgs; [    # TODO: figure out which should be modularized for, say, headless machines
    

    # tailscale
    tailscale

    # Font config
      (nerdfonts.override { fonts = [ "FiraCode" ]; })


    ## Keybinds
      kanata                        # keybinds                                  https://github.com/jtroo/kanata
    
    # archive                   # archive                                   # archive
      zip                           # zip                                       http://www.info-zip.org/
      unzip                         # unzip                                     http://www.info-zip.org/
      p7zip                         # p7zip                                     https://github.com/p7zip-project/p7zip
  
    # bash                      # bash                                      # bash
      shellcheck                    # bash linter                               https://www.shellcheck.net/
      shfmt                         # bash formatter                            https://github.com/mvdan/sh
    
    # cli tools                 # cli tools                                 # CLI tools
      entr                          # run commands when files change            https://github.com/eradman/entr
      pciutils                      # lspci                                     https://mj.ucw.cz/sw/pciutils/
      topgrade                      # upgrade all the things (nix sorta broken) https://github.com/topgrade-rs/topgrade
  
    # dev                       #  dev                                      # dev
      asdf-vm                       # asdf (use dev shells instead)             https://github.com/asdf-vm/asdf-vm
      diffutils                     # `diff` utils                              https://github.com/ogham/diffutils
      direnv                        # per-directory environments                https://github.com/direnv/direnv
      gnumake                       # gnumake                                   https://github.com/ogham/gnumake
      lazydocker                    # TUI docker interface                      https://github.com/jesseduffield/lazydocker
      riffdiff                      # provides `riff`, where-in-line diff       https://github.com/walles/riff
      python3                       # system python, zsh complains without      https://python.org
      ruff                          # python linter                             https://github.com/astral-sh/ruff
      ruff-lsp                      # ruff integration with vscode              https://github.com/astral-sh/ruff-lsp
      sqlite                        # sqlite                                    https://www.sqlite.org/
    # editors                   # editors                                   # editors
      nano                          # text editor                               https://www.nano-editor.org/
      nanorc                        # nano syntax highlighting                  https://github.com/scopatz/nanorc
      neovim                        # text editor                               https://neovim.io/

    # file transfer             # file transfer                             # file transfer
      aria2                         # cli download manager                      https://aria2.github.io/
      magic-wormhole-rs             # easy transfer arbitrary files encrypted   https://github.com/magic-wormhole/magic-wormhole.rs
      rsync                         # up hill both ways                         https://linux.die.net/man/1/rsync
  
    # git                       # git                                       # git  
      gh                            # github cli                                https://github.com/cli/cli
      git                           # git scm                                   https://git-scm.com
      delta                         # `delta` - git diff                        https://github.com/dandavison/delta
      lazygit                       # TUI git interface                         https://github.com/jesseduffield/lazygit
      commitizen                    # commitizen                                https://github.com/commitizen-tools/commitizen
  
    # help systems              # help systems                              # Help Systems
      cheat                         # cli cheatsheets                           https://github.com/cheat/cheat
      tldr                          # better man pages                          https://tldr.sh/
  
    # internet                  # internet                                  # internet
      curl                          # `curl`                                    https://curl.se/download.html
      dnsutils                      # `dig` + `nslookup`                        https://www.isc.org/bind/
      iftop                         # network monitor                           https://pdw.ex-parrot.com/iftop/
      ipcalc                        # IP address calculator                     https://gitlab.com/ipcalc/ipcalc
      iperf3                        # network tools                             https://software.es.net/iperf/
      ldns                          # provides `drill` a `dig` replacement      https://www.nlnetlabs.nl/projects/ldns/about/
      mtr                           # traceroute + ping                         https://www.bitwizard.nl/mtr/
      nmap                          # network scanner                           http://www.nmap.org/
      socat                         # openbsd-netcat replacement                http://www.dest-unreach.org/socat/
      wget                          # its like curl but different               https://www.gnu.org/software/wget/
      whois                         # whois lookup                              https://packages.qa.debian.org/w/whois.html
  
    # linux debugging           # linux debugging                           # linux debugging
      lsof                          # list open files                           https://linux.die.net/man/1/lsof
      

    # multi-machine             # multi-machine                             # multi-machine
      mosh                          # ssh but better (but abandoned)            https://mosh.org/
  
    # nix                       # nix                                       # Nix - Move some of these into dev shells
      comma                         # `,` run things without installing them    https://github.com/nix-community/comma
      deadnix                       # scan for dead nix code                    https://github.com/astro/deadnix
      manix                         # nix man pages                             https://github.com/nix-community/manix
      niv                           # like flakes but worse
      nix-diff                      # diff nix code                             https://hackage.haskell.org/package/nix-diff
      nix-du                        # nix-store analysis                        https://github.com/symphorien/nix-du
      nix-health                    # check nix issues                          https://github.com/juspay/nix-health
      nix-init                      # nix packages from URLs                    https://github.com/nix-community/nix-init
      nix-index                     # nix store index search                    https://github.com/nix-community/nix-index
      nix-output-monitor            # `nom`                                     https://github.com/maralorn/nix-output-monitor
      nix-tree                      # view dependency graph                     https://hackage.haskell.org/package/nix-tree
      nix-zsh-completions           # nix shell completions                     https://github.com/nix-community/nix-zsh-completions
      nixfmt                        # format nix code                           https://github.com/serokell/nixfmt
      nurl                          # nix fetcher calls from repository URLs    https://github.com/nix-community/nurl
      nvd                           # nix package version diff                  https://gitlab.com/khumba/nvd
      statix                        # antipattern linter                        https://github.com/nerdypepper/statix


  
    # shell                     # shell                                     # shell
      atuin                         # shell history                             https://github.com/ellie/atuin
      bash-completion               # bash complete                             https://github.com/scop/bash-completion
      bat                           # `cat` alternative                         https://github.com/sharkdp/bat
      bat-extras.batdiff            # bat diff                                  https://github.com/eth-p/bat-extras
      bat-extras.batgrep            # bat grep                                  https://github.com/eth-p/bat-extras
      bat-extras.batman             # TODO: broken                              https://github.com/eth-p/bat-extras
      bat-extras.batpipe            # bat pipe                                  https://github.com/eth-p/bat-extras
      bat-extras.batwatch           # bat watch                                 https://github.com/eth-p/bat-extras
      bat-extras.prettybat          # prettybat                                 https://github.com/eth-p/bat-extras
      broot                         # `br` - tree alternative                   https://github.com/Canop/broot
      btop                          # `htop` alternative                        https://github.com/aristocratos/btop
      du-dust                       # `du` alternative                          https://github.com/bootandy/dust
      duf                           # `df` alternative                          https://github.com/muesli/duf
      eza                           # `ls` alternative                          https://github.com/ogham/eza
      fd                            # `find` alternative                        https://github.com/sharkdp/fd
      file                          # `file` show filetype                      https://darwinsys.com/file
      fzf                           # fuzzy finder and fast TUI via piping      https://github.com/junegunn/fzf
      glow                          # terminal markdown viewer                  https://github.com/charmbracelet/glow
      hyfetch                       # neofetch replacement                      https://github.com/hykilpikonna/HyFetch
      jc                            # jc converts output into JSON or YAML      https://github.com/kellyjonbrazil/jc
      jq                            # json query                                https://github.com/stedolan/jq
      mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
      moar                          # better pager                              https://github.com/walles/moar
      nnn                           # TUI file manager                          https://github.com/jarun/nnn
      nushell                       # nushell                                   https://github.com/nushell/nushell
      ripgrep                       # `rg` grep replacement                     https://github.com/BurntSushi/ripgrep
      tree                          # necessary for some zi things              https://oldmanprogrammer.net/source.php?dir=projects/tree
      starship                      # shell prompt                              https://github.com/starship/starship
      vivid                         # LS_COLORS generator                       https://github.com/sharkdp/vivid
      which                         # `which`                                   https://www.gnu.org/software/which/
      yq-go                         # yaml query                                https://github.com/mikefarah/yq
      zellij                        # terminal multiplexer/tiler                https://zellij.dev/
      zoxide                        # smarter cd                                https://github.com/ajeetdsouza/zoxide
    
    # bash                      # bash                                      # bash
      inshellisense                 # intellisense type shell complete          https://github.com/microsoft/inshellisense
      blesh                         # better bash line editor                   https://github.com/akinomyoga/ble.sh
  
    
    # TODO: move to system config
        
  
  ];  
  # programs are packages you set extra pre-defined options in.
  #   google 'home-manager option search' to see how to find them.

  programs.nix-index = { 
    enable = true;
    # enableZshIntegration = true;  # conflicts with command-not-found
    # enableBashIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.micro = {                # editor for phone-ssh
  enable = true;
  settings = {
    autoclose = false;
    backup = false;
    autosu = true;
    cursorline  = true;
    colorscheme = "dukeubuntu-tc";
    difgutter = true;
    eofnewline = true;
    fastdirty = true;
    ignorecase = false;
    keyenu = true;
    mkparents = true;
    savehistory = false;
    tabsize = 2;
    tsbstospaces = true;
    colorcolumn = 81;
    indentchar = "·";
    multiopen = "hsplit";
    parsecursor = true;
    linter = true;
    comment = true;
    tabstospaces = true;
  };
  };
  }


  # GPU diagnostic packages live in ../000-nire-durandal-host/_gpu.nix
  # GUI-primary packages live in ./elly.gui-pkgs.nix

  # Things to look into:
    # MyNixOS
    # nixpkgs-wayland
    # nix-direnv
    # haumea                # nix configuration tool that allows you to just use the filesystem instead of imports 
    # flakelight            # less flake boilerplate
    # flake-utils
    # flake-utils-plus
    # flake-parts           # module system for flakes
    # devshell              # like virtualenv
    # devbox                # isolated development shells, maybe like the above
    # devenv                # same
    # nixos-shell           # easy VMs
    # nix-index             # quickly locate packages providing a certain file
    # nix-prefetch          # determine hash of fixed-output derivations such as package source
