{pkgs, ...}:
{
  home.packages = with pkgs; [
  # TODO: mkIf and mkEnable, have it be essential vs optional
  # editors
    nano                      # text editor
    nanorc                    # nano syntax highlighting
    neovim                    # text editor
    helix


  # network
    aria2                     # download manager
    curl                      # `curl`
    dnsutils                  # `dig` + `nslookup`
    iftop                     # network monitor
    ipcalc                    # IP address calculator
    iperf3                    # network tools
    ldns                      # provides `drill` a `dig` replacement
    mtr                       # traceroute
    nmap                      # network scanner
    socat                     # openbsd-netcat replacement
    wget                      # its like curl but different
    whois                     # whois lookup



  # compression
    zip
    unzip
    p7zip                     # archive

  # dev
    # general
      asdf-vm                   # asdf version manager https://github.com/asdf-vm/asdf-vm
      diffutils                 # `diff` utils https://github.com/ogham/diffutils
      direnv                    # per-directory environments https://github.com/direnv/direnv
      gh                        # github cli https://github.com/cli/cli
      git                       # git scm
      delta                     # `delta` - git diff https://github.com/dandavison/delta
      gnumake                   # make replacement https://github.com/ogham/gnumake
    # shell script dev
      shellcheck
      shfmt
    # TUI dev utilities
      lazydocker                # TUI docker browser
      lazygit                   # TUI git browser

  # system python tools
    python312Packages.ipdb
    python312Packages.ipython
  # System call monitoring
    # dtrace # TODO FIND PACKAGE NAME            # global overview of a running system, tracing of individual functions, etc
    lsof                      # list open files
    ltrace                    # library call tracer
    strace                    # system call tracer

  # shell
    atuin                     # shell history https://github.com/ellie/atuin
    bash-completion           # bash complete
    bat                       # `cat` alternative - add-ons in own section
    eza                       # `ls` replacement https://github.com/ogham/eza
    fd                        # `find` replacement https://github.com/sharkdp/fd
    fzf                       # fuzzy finder https://github.com/junegunn/fzf
    glow                      # terminal markdown viewer https://github.com/charmbracelet/glow
    jc                        # jc converts the output of many commands, file-types, and strings to JSON or YAML
    jq                        # json query https://github.com/stedolan/jq
    mc                        # midnight commander
    nnn                       # file manager
    ripgrep                   # `rg` grep replacement
    tree                      # necessary for some zi things
    yq-go                     # yaml query https://github.com/mikefarah/yq
    zellij                    # terminal multiplexer/tiler
    zoxide                    # smarter cd
    file                      # 
    which                     # 
    


  
  # help systems
    cheat                     # cli cheatsheets https://github.com/cheat/cheat
    tldr                      # better man pages
  
  # system utilities
    broot                     # `br` - tree replacement https://github.com/Canop/broot
    btop                      # `htop` replacement https://github.com/aristocratos/btop
    du-dust                   # `du` alternative https://github.com/bootandy/dust
    duf                       # `df` alternative https://github.com/muesli/duf
    entr                      # run commands when files change https://github.com/eradman/entr
    ethtool                   # 
    iotop                     # io monitoring
    mlocate                   # locate from database built with `updatedb`
    pciutils                  # lspci
    sysstat                   # system stats
    topgrade                  # upgrade all the things
    usbutils                  # lsusb
    hyfetch                   # neofetch replacement

  # cpu
    auto-cpufreq              # https://github.com/AdnanHodzic/auto-cpufreq
    lm_sensors  
    libinput                  # libinput.  I forget what I need this for

  # remote
    mosh                      # ssh but better


  # nix
    manix # nix man pages
    nix-zsh-completions       # nix shell completions
    nix-du                    # nix-store analysis
    nix-output-monitor        # 
    nix-tree                  # view dependency graph
    alejandra                 # nix formatter
  # file transfer
    magic-wormhole-rs         # transfer arbitrary files easy and encrypted
  
  # media
    cmus                      # TUI media player

    # bat-extras
      bat-extras.batdiff
      bat-extras.batgrep
      bat-extras.batman
      bat-extras.batpipe
      bat-extras.batwatch
      bat-extras.prettybat






  ];
}
