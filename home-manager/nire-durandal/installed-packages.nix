{ pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{
    home.packages = with pkgs; [
      # TODO: make this targeted by home manager, consolidate other modules into
      # larger files and treat the files as folders
      # We don't have enough machines to waste brain on it yet.

      # TODO: figure out which should be modularized for, say, headless machines

      # Font config
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
      
      # browsers                  # browsers
        kdePackages.konqueror       # one of the best `info` file pagers
        firefox                     # firefox is installed as a system package.  this might not work.
      # comms                     # comms
        cinny-desktop               # matrix client
        telegram-desktop            # telegram (unsecure)
        discord                     # discord (all the tech support happens here)
        wire-desktop                # old encrypted chat client, my ex used it
        signal-desktop              # encrypted chat everone uses
        keybase-gui                 # encrypted chat almost no one uses
          keybase                   # see above
        zoom-us                     # less features than facetime somehow
      # text-input                # text input
        emote                       # gui emoji picker
        qmk                         # qmk keyboard manager https://github.com/qmk/qmk_firmware
      # multi-machine             # multi-machine
        mosh                        # ssh but better
        input-leap                  # soft-KVM, synergy/barrier fork
      # media and sound           # media and sound
        vlc                         # video player
        qpwgraph                    # sound mixer
      # image editing             # image editing
        gimp                        # GNU Image Manipulation Program.
      # gpu diagnostics
        vulkan-tools                #
        glxinfo                     #
        clinfo                      #
        amdgpu_top                  #
      # desktop dev
        vscode-fhs                  # vscode
        github-desktop              # github-desktop
      # dev cli
        asdf-vm                     # asdf version manager https://github.com/asdf-vm/asdf-vm
        diffutils                   # `diff` utils https://github.com/ogham/diffutils
        direnv                      # per-directory environments https://github.com/direnv/direnv
        gnumake                     # https://github.com/ogham/gnumake
        lazydocker                  # TUI docker interface
        # Git
          gh                        # github cli https://github.com/cli/cli
          git                       # git scm
          delta                     # `delta` - git diff https://github.com/dandavison/delta
          lazygit                   # TUI git interface
        # Bash
          shellcheck                # bash linter 
          shfmt                     # bash formatter
        # Linux debugging
          lsof                      # list open files
          ltrace                    # library call tracer
          strace                    # system call tracer
          # dtrace # TODO FIND PACKAGE NAME            # global overview of a running system, tracing of individual functions, etc
      # TUI editors
        nano                        # text editor
          nanorc                    # nano syntax highlighting
        neovim                      # text editor
        helix                       # text editor
      # 'productivity'
        obsidian                    # pkm
        libreoffice-qt              # office
      # terminals
        kitty                       # gpu accelerated terminal
          kitty-img                 # kitty image rendering engine, like sixel
      # get things from strangers
        magic-wormhole-rs           # transfer arbitrary files easy and encrypted
        rsync                       # up hill both ways
        aria2                       # cli download manager
        curl                        # `curl`
        wget                        # its like curl but different
      # networking
        dnsutils                    # `dig` + `nslookup`
        iftop                       # network monitor
        ipcalc                      # IP address calculator
        iperf3                      # network tools
        ldns                        # provides `drill` a `dig` replacement
        mtr                         # traceroute
        nmap                        # network scanner
        socat                       # openbsd-netcat replacement
        whois                       # whois lookup
      # Archive
        zip
        unzip
        p7zip
      # shell
        atuin                       # shell history https://github.com/ellie/atuin
        bash-completion             # bash complete
        bat                         # `cat` alternative - add-ons in own section
        bat-extras.batdiff          #
        bat-extras.batgrep          #
        bat-extras.batman           #
        bat-extras.batpipe          #
        bat-extras.batwatch         #
        bat-extras.prettybat        #
        broot                       # `br` - tree replacement https://github.com/Canop/broot
        btop                        # `htop` replacement https://github.com/aristocratos/btop
        du-dust                     # `du` alternative https://github.com/bootandy/dust
        duf                         # `df` alternative https://github.com/muesli/duf
        eza                         # `ls` replacement https://github.com/ogham/eza
        fd                          # `find` replacement https://github.com/sharkdp/fd
        file                        # 
        fzf                         # fuzzy finder https://github.com/junegunn/fzf
        glow                        # terminal markdown viewer https://github.com/charmbracelet/glow
        hyfetch                     # neofetch replacement
        jc                          # jc converts the output of many commands, file-types, and strings to JSON or YAML
        jq                          # json query https://github.com/stedolan/jq
        mc                          # midnight commander TUI file manager
        nnn                         # TUI file manager
        ripgrep                     # `rg` grep replacement
        tree                        # necessary for some zi things
        which                       # 
        yq-go                       # yaml query https://github.com/mikefarah/yq
        zellij                      # terminal multiplexer/tiler
        zoxide                      # smarter cd
      # help systems    
        cheat                       # cli cheatsheets https://github.com/cheat/cheat
        tldr                        # better man pages
      # cli tools
        entr                        # run commands when files change https://github.com/eradman/entr
        ethtool                     # 
        iotop                       # io monitoring
        mlocate                     # locate from database built with `updatedb`
        pciutils                    # lspci
        sysstat                     # system stats
        topgrade                    # upgrade all the things
        usbutils                    # lsusb
      # system tools
        auto-cpufreq                # https://github.com/AdnanHodzic/auto-cpufreq
        lm_sensors  
        libinput  
      # nix
        manix # nix man pages
        nix-zsh-completions         # nix shell completions
        nix-du                      # nix-store analysis
        nix-output-monitor          # 
        nix-tree                    # view dependency graph
        nixfmt                      # format nix code
        nix-health                  # check nix issues
        comma                       # like nix-shell -p but faster, run things by prefixing with , without installing them
        deadnix                     # scan for dead nix code
        nix-diff                    # diff nix code
        nix-init                    # generate nix packages from URLs
        nurl                        # generate nix fetcher calls from repository URLs
        nvd                         # nix package version diff
        statix                      # antipattern linter
  ];
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
