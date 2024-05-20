{ lib, config, pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{
  options = {

    _hm-pkg.gui.enable                   = lib.mkEnableOption "Enables GUI packages";
      _hm-pkg.gui.browsers.enable          = lib.mkEnableOption "gui.Browsers";
      _hm-pkg.gui.comms.enable             = lib.mkEnableOption "gui.comms";
      _hm-pkg.gui.text-input.enable        = lib.mkEnableOption "gui.text input";
      _hm-pkg.gui.remote.enable            = lib.mkEnableOption "gui.remote";
      _hm-pkg.gui.media.enable             = lib.mkEnableOption "gui.media";
      _hm-pkg.gui.sound.enable             = lib.mkEnableOption "gui.sound";
      _hm-pkg.gui.image-editing.enable     = lib.mkEnableOption "gui.image editing";
      _hm-pkg.gui.keyboard-config.enable   = lib.mkEnableOption "gui.keyboard config";
      _hm-pkg.gui.system-util.enable       = lib.mkEnableOption "gui.System utilities";
      _hm-pkg.gui.dev.enable               = lib.mkEnableOption "gui.dev-tools";
      _hm-pkg.gui.productivity.enable      = lib.mkEnableOption "gui.productivity";
      _hm-pkg.gui.terminal.enable          = lib.mkEnableOption "gui.terminal";
      _hm-pkg.font.enable              = lib.mkEnableOption "font";


    _hm-pkg.cli.enable                   = lib.mkEnableOption "enable CLI packages";
      _hm-pkg.cli.editors.enable            = lib.mkEnableOption "Cli editor packages";
      _hm-pkg.cli.network.enable            = lib.mkEnableOption "cli network packages";
      _hm-pkg.cli.archive.enable            = lib.mkEnableOption "cli archive packages";

      _hm-pkg.cli.dev.general.enable        = lib.mkEnableOption "cli general dev packages";
      _hm-pkg.cli.dev.git.enable            = lib.mkEnableOption "cli git packages";
      _hm-pkg.cli.dev.docker.enable         = lib.mkEnableOption "cli docker tools";
      _hm-pkg.cli.dev-bash-tools.enable     = lib.mkEnableOption "cli shell script tools";

      _hm-pkg.cli.sysadmin.enable           = lib.mkEnableOption "cli sysadmin packages";
      _hm-pkg.cli.shell.enable              = lib.mkEnableOption "cli shell packages";
      _hm-pkg.cli.system-util.enable        = lib.mkEnableOption "System utilities";
      _hm-pkg.cli.cpu.enable                = lib.mkEnableOption "CPU utilities";
      _hm-pkg.cli.help.enable               = lib.mkEnableOption "cli help packages";
      _hm-pkg.cli.remote.enable             = lib.mkEnableOption "Remote utilities";  
      _hm-pkg.cli.nix.enable                = lib.mkEnableOption "Nix utilities";
      _hm-pkg.cli.file-transfer.enable      = lib.mkEnableOption "File transfer utilities";
      _hm-pkg.cli.media.enable              = lib.mkEnableOption "Media utilities";
      _hm-pkg.cli.shell.bat-extras.enable   = lib.mkEnableOption "bat-extras";
      _hm-pkg.sys.python.enable             = lib.mkEnableOption "System python"; 




    _hm-pkg.gaming.enable   = lib.mkEnableOption "Gaming packages";
    _hm-pkg.wayland.enable  = lib.mkEnableOption "Wayland packages";

  };

  config = [
    lib.mkIf config._hm-pkg.font.enable {
      fonts.fontconfig.enable = true; 
      home.packages = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
      ];
    }
    
    lib.mkIf config._hm-pkg.gui.enable {
      
    } lib.mkIf config._hm-pkg.gui.browsers.enable {
      home.packages = with pkgs; [
        kdePackages.konqueror       # one of the best `info` file pagers
        # where's firefox lol.  system config?
      ];
    } lib.mkIf config._hm-pkg.gui.comms.enable {
      home.packages = with pkgs; [
        cinny-desktop               # matrix client
        telegram-desktop            # telegram (unsecure)
        discord                     # discord (all the tech support happens here)
        wire-desktop                # old encrypted chat client, my ex used it
        signal-desktop              # encrypted chat everone uses
        keybase-gui                 # encrypted chat almost no one uses
        keybase                     # see above
        zoom-us                     # less features than facetime somehow
      ];
    } lib.mkIf config._hm-pkg.gui.text-input.enable {
      home.packages = with pkgs; [
        emote                       # gui emoji picker
      ];
    } lib.mkIf config._hm-pkg.gui.remote.enable {
      home.packages = with pkgs; [
        input-leap                  # KVM, synergy/barrier fork
      ];
    } lib.mkIf config._hm-pkg.gui.media.enable {
      home.packages = with pkgs; [
        vlc                         # video player
      ];
    } lib.mkIf config._hm-pkg.gui.sound.enable {
      home.packages = with pkgs; [
        qpwgraph                    # sound mixer
      ];
    } lib.mkIf config._hm-pkg.gui.image-editing.enable {
      home.packages = with pkgs; [
        gimp                        # image editor
      ];
    } lib.mkIf config._hm-pkg.gui.keyboard-config.enable {
      home.packages = with pkgs; [
        qmk                         # qmk keyboard manager https://github.com/qmk/qmk_firmware
      ];
    } lib.mkIf config._hm-pkg.gui.system-util.enable {
      home.packages = with pkgs; [
        vulkan-tools                #
        glxinfo                     #
        clinfo                      #
        amdgpu_top                  #
      ];
    } lib.mkIf config._hm-pkg.gui.dev.enable {
      home.packages = with pkgs; [
        vscode-fhs                  # vscode
        github-desktop              # github-desktop
      ];
    } lib.mkIf config._hm-pkg.gui.productivity.enable {
      home.packages = with pkgs; [
        obsidian                    # pkm
        libreoffice-qt              # office
      ];
    } lib.mkIf config._hm-pkg.gui.terminal.enable {
      home.packages = with pkgs; [
        kitty                       # gpu accelerated terminal
        kitty-img                   # kitty image rendering engine, like sixel
      ];
    } lib.mkIf config._hm-pkg.cli.editors.enable  {
      home.packages = with pkgs; [
        nano                        # text editor
        nanorc                      # nano syntax highlighting
        neovim                      # text editor
        helix                       # text editor
      ];
    } lib.mkIf config._hm-pkg.cli.network.enable {
      home.packages = with pkgs; [
        aria2                       # download manager
        curl                        # `curl`
        dnsutils                    # `dig` + `nslookup`
        iftop                       # network monitor
        ipcalc                      # IP address calculator
        iperf3                      # network tools
        ldns                        # provides `drill` a `dig` replacement
        mtr                         # traceroute
        nmap                        # network scanner
        socat                       # openbsd-netcat replacement
        wget                        # its like curl but different
        whois                       # whois lookup
        
      ];
    } lib.mkIf config._hm-pkg.cli.files.enable { 
      home.packages = with pkgs; [
        zip
        unzip
        p7zip
        magic-wormhole-rs           # transfer arbitrary files easy and encrypted
        rsync                       # up hill both ways
      ];
    } lib.mkIf config._hm-pkg.cli.dev.general.enable { 
      home.packages = with pkgs; [
        asdf-vm                     # asdf version manager https://github.com/asdf-vm/asdf-vm
        diffutils                   # `diff` utils https://github.com/ogham/diffutils
        direnv                      # per-directory environments https://github.com/direnv/direnv
        gnumake                     # https://github.com/ogham/gnumake
      ];
    } lib.mkIf config._hm-pkg.cli.dev.git.enable { 
      home.packages = with pkgs; [
        gh                          # github cli https://github.com/cli/cli
        git                         # git scm
        delta                       # `delta` - git diff https://github.com/dandavison/delta
        lazygit                     # TUI git interface
      ];
    } lib.mkIf config._hm-pkg.cli.dev.docker.enable {
      home.packages = with pkgs; [ 
        lazydocker                  # TUI docker interface
      ]; 
    } lib.mkIf config._hm-pkg.cli.dev-bash-tools.enable {
      home.packages = with pkgs; [                  # fix descriptions
        shellcheck                  # bash linter 
        shfmt                       # bash formatter
      ];
    } lib.mkIf config._hm-pkg.cli.sysadmin.enable {
      home.packages = with pkgs; [
        lsof                      # list open files
        ltrace                    # library call tracer
        strace                    # system call tracer
        # dtrace # TODO FIND PACKAGE NAME            # global overview of a running system, tracing of individual functions, etc
      ];
    } lib.mkIf config._hm-pkg.cli.shell.enable {
      home.packages = with pkgs; [
        atuin                       # shell history https://github.com/ellie/atuin
        bash-completion             # bash complete
        bat                         # `cat` alternative - add-ons in own section
        bat-extras.batdiff          #
        bat-extras.batgrep          #
        bat-extras.batman           #
        bat-extras.batpipe          #
        bat-extras.batwatch         #
        bat-extras.prettybat        #
        eza                         # `ls` replacement https://github.com/ogham/eza
        fd                          # `find` replacement https://github.com/sharkdp/fd
        file                        # 
        fzf                         # fuzzy finder https://github.com/junegunn/fzf
        glow                        # terminal markdown viewer https://github.com/charmbracelet/glow
        jc                          # jc converts the output of many commands, file-types, and strings to JSON or YAML
        jq                          # json query https://github.com/stedolan/jq
        mc                          # midnight commander
        nnn                         # file manager
        ripgrep                     # `rg` grep replacement
        tree                        # necessary for some zi things
        which                       # 
        yq-go                       # yaml query https://github.com/mikefarah/yq
        zellij                      # terminal multiplexer/tiler
        zoxide                      # smarter cd
      ];
    } lib.mkIf config._hm-pkg.cli.help.enable {
      home.packages = with pkgs; [
        cheat                       # cli cheatsheets https://github.com/cheat/cheat
        tldr                        # better man pages
      ];
    } lib.mkIf config._hm-pkg.cli.system-util.enable {
      home.packages = with pkgs; [
        broot                       # `br` - tree replacement https://github.com/Canop/broot
        btop                        # `htop` replacement https://github.com/aristocratos/btop
        du-dust                     # `du` alternative https://github.com/bootandy/dust
        duf                         # `df` alternative https://github.com/muesli/duf
        entr                        # run commands when files change https://github.com/eradman/entr
        ethtool                     # 
        hyfetch                     # neofetch replacement
        iotop                       # io monitoring
        mlocate                     # locate from database built with `updatedb`
        pciutils                    # lspci
        sysstat                     # system stats
        topgrade                    # upgrade all the things
        usbutils                    # lsusb
      ];
    } lib.mkIf config._hm-pkg.cli.cpu.enable {
      home.packages = with pkgs; [
        auto-cpufreq                # https://github.com/AdnanHodzic/auto-cpufreq
        lm_sensors  
        libinput  
      ];
    } lib.mkIf config._hm-pkg.cli.remote.enable {
      home.packages = with pkgs; [
        mosh                        # ssh but better
      ];
    } lib.mkIf config._hm-pkg.cli.nix.enable {
      home.packages = with pkgs; [
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
