{ pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{



  
    home.packages = with pkgs; [    # TODO: figure out which should be modularized for, say, headless machines
      
      # Font config
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
      
      # browsers                  # browsers
        kdePackages.konqueror       # one of the best `info` file pagers
        firefox                     # firefox is installed as a system package.  this might not work.
      # comms                     # comms
        cinny-desktop               # matrix client
        discord                     # discord (all the tech support happens here)
        keybase-gui                 # encrypted chat almost no one uses
          keybase                   # see above
        obs-studio                  # screen recording / streaming
        signal-desktop              # encrypted chat everone uses
        teamspeak_client            # teamspeak game comms
        telegram-desktop            # telegram (unsecure)
        wire-desktop                # old encrypted chat client, my ex used it
        zoom-us                     # less features than facetime somehow
      # keyboard/mouse/text       # keyboard/mouse/text
        emote                       # gui emoji picker
        qmk                         # qmk keyboard manager                      https://github.com/qmk/qmk_firmware
        piper                       # logitech/razer mouse manager              https://github.com/soxoj/piper
      # multi-machine             # multi-machine
        mosh                        # ssh but better
        input-leap                  # soft-KVM, synergy/barrier fork
      # media and sound           # media and sound
        vlc                         # video player
        qpwgraph                    # sound mixer
      # image editing             # image editing
        gimp                        # GNU Image Manipulation Program.
      # gpu diagnostics           # gpu diagnostics
        vulkan-tools                # vulkan-tools
        glxinfo                     # glxinfo
        clinfo                      # clinfo
        amdgpu_top                  # amdgpu_top gpu monitor
      # desktop dev               # desktop dev
        vscode-fhs                  # vscode
        github-desktop              # github-desktop
      # dev cli tools             # dev cli tools
        asdf-vm                     # asdf (use dev shells instead)             https://github.com/asdf-vm/asdf-vm
        diffutils                   # `diff` utils                              https://github.com/ogham/diffutils
        direnv                      # per-directory environments                https://github.com/direnv/direnv
        gnumake                     # gnumake                                   https://github.com/ogham/gnumake
        lazydocker                  # TUI docker interface
        # Git                     # Git
          gh                        # github cli                                https://github.com/cli/cli
          git                       # git scm
          delta                     # `delta` - git diff                        https://github.com/dandavison/delta
          lazygit                   # TUI git interface
        # Bash                    # Bash
          shellcheck                # bash linter 
          shfmt                     # bash formatter
        # Linux debugging         # Linux debugging
          lsof                      # list open files
          ltrace                    # library call tracer
          strace                    # system call tracer
          # dtrace                  # TODO FIND PACKAGE NAME
      # TUI editors               # TUI editors
        nano                        # text editor
        nanorc                      # nano syntax highlighting
        neovim                      # text editor
        helix                       # text editor
      # 'productivity'            # 'productivity'
        obsidian                    # pkm
        libreoffice-qt              # office
      # terminals                 # terminals
        kitty                       # gpu accelerated terminal
        kitty-img                   # kitty image rendering engine, like sixel
      # get things from strangers  # get things from strangers
        magic-wormhole-rs           # transfer arbitrary files easy and encrypted
        rsync                       # up hill both ways
        aria2                       # cli download manager
        curl                        # `curl`
        wget                        # its like curl but different
      # networking                # networking
        dnsutils                    # `dig` + `nslookup`
        iftop                       # network monitor
        ipcalc                      # IP address calculator
        iperf3                      # network tools
        ldns                        # provides `drill` a `dig` replacement
        mtr                         # traceroute
        nmap                        # network scanner
        socat                       # openbsd-netcat replacement
        whois                       # whois lookup
      # Archive                   # Archive
        zip                         # zip
        unzip                       # unzip
        p7zip                       # p7zip
      # shell                     # shell
        atuin                       # shell history                             https://github.com/ellie/atuin
        bash-completion             # bash complete
        bat                         # `cat` alternative
        bat-extras.batdiff          # bat diff
        bat-extras.batgrep          # bat grep
        bat-extras.batman           # TODO: broken
        bat-extras.batpipe          # bat pipe
        bat-extras.batwatch         # bat watch
        bat-extras.prettybat        # prettybat
        broot                       # `br` - tree alternative                   https://github.com/Canop/broot
        btop                        # `htop` alternative                        https://github.com/aristocratos/btop
        du-dust                     # `du` alternative                          https://github.com/bootandy/dust
        duf                         # `df` alternative                          https://github.com/muesli/duf
        eza                         # `ls` alternative                          https://github.com/ogham/eza
        fd                          # `find` alternative                        https://github.com/sharkdp/fd
        file                        # `file`
        fzf                         # fuzzy finder and fast TUI via piping      https://github.com/junegunn/fzf
        glow                        # terminal markdown viewer                  https://github.com/charmbracelet/glow
        hyfetch                     # neofetch replacement
        jc                          # jc converts configs etc into JSON or YAML
        jq                          # json query                                https://github.com/stedolan/jq
        mc                          # midnight commander TUI file manager
        moar                        # better pager
        nnn                         # TUI file manager
        ripgrep                     # `rg` grep replacement
        tree                        # necessary for some zi things
        which                       # `which`
        yq-go                       # yaml query                                https://github.com/mikefarah/yq
        zellij                      # terminal multiplexer/tiler
        zoxide                      # smarter cd
      # help systems              # help systems
        cheat                       # cli cheatsheets                           https://github.com/cheat/cheat
        tldr                        # better man pages
      # cli tools                 # cli tools
        entr                        # run commands when files change            https://github.com/eradman/entr
        ethtool                     # ethtool
        iotop                       # io monitoring
        mlocate                     # locate from database built with `updatedb`
        pciutils                    # lspci
        sysstat                     # system stats
        topgrade                    # upgrade all the things
        usbutils                    # lsusb
      # system tools              # system tools
        auto-cpufreq                # auto-cpufreq                              https://github.com/AdnanHodzic/auto-cpufreq
        lm_sensors                  # lm_sensors
        libinput                    # TODO: I forget what I need this for.
      # nix                       # nix
        manix                       # nix man pages
        nix-zsh-completions         # nix shell completions
        nix-du                      # nix-store analysis
        nix-output-monitor          # `nom`
        nix-tree                    # view dependency graph
        nixfmt                      # format nix code
        nix-health                  # check nix issues
        comma                       # `,` run things without installing them
        deadnix                     # scan for dead nix code
        nix-diff                    # diff nix code
        nix-init                    # nix packages from URLs
        nurl                        # nix fetcher calls from repository URLs
        nvd                         # nix package version diff
        statix                      # antipattern linter
      # Games                     # Games
        lutris                      # lutris game launcher
        # steam is in the nix config
        protonup-qt                 # proton installer/updater
        protontricks                # protontricks
        wineWowPackages.waylandFull # Wine for wayland
        steamtinkerlaunch           # steamtinkerlaunch
        glfw                        # TODO: redundant, in system config
        dxvk                        # TODO: redundant, in system config
      # Wayland                   # Wayland
        wl-clipboard                # clipboard in wayland
          wl-clipboard-x11          # clipboard in xwayland
        wayland-utils               # wayland-utils
        egl-wayland                 # who knows what this is for
        

  ];
  # programs are packages you set extra pre-defined options in.
  #   google 'home-manager option search' to see how to find them.
  programs.micro = {          # editor for phone-ssh
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
