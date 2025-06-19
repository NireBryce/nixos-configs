{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
    # Storage stats
        du-dust                       # `du` alternative https://github.com/bootandy/dust
        duf                           # `df` alternative https://github.com/muesli/duf
    # shell-specific
        blesh                         # zsh line editor tricks for bash https://github.com/akinomyoga/ble.sh
        bash-completion               # bash completions https://github.com/scop/bash-completion
    # search utils
        fd                            # `find` alternative https://github.com/sharkdp/fd
        ripgrep                       # `rg` very fast grep replacement https://github.com/BurntSushi/ripgrep
        fselect # idk what this is
    
    
    
    
    
    # nix-util
        # todo: fix comma
        # comma                         # `,` run things without installing them https://github.com/nix-community/comma
        deadnix                       # scan for dead nix code https://github.com/astro/deadnix
        manix                         # nix man pages https://github.com/nix-community/manix
        nix-diff                      # diff nix code https://hackage.haskell.org/package/nix-diff
        nix-du                        # nix-store analysis https://github.com/symphorien/nix-du
        nix-health                    # check nix issues https://github.com/juspay/nix-health
        nix-init                      # nix packages from URLs https://github.com/nix-community/nix-init

        nix-output-monitor            # `nom`                                     https://github.com/maralorn/nix-output-monitor
        nix-tree                      # view dependency graph                     https://hackage.haskell.org/package/nix-tree
        nix-zsh-completions           # nix shell completions                     https://github.com/nix-community/nix-zsh-completions
        nixfmt                        # format nix code                           https://github.com/serokell/nixfmt
        nurl                          # nix fetcher calls from repository URLs    https://github.com/nix-community/nurl
        nvd                           # nix package version diff                  https://gitlab.com/khumba/nvd
        statix                        # antipattern linter                        https://github.com/nerdypepper/statix
    
    
    
    
    
    # cli file browsers
        mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
        yazi
    # interpreters
        python3                       # system python, zsh complains without      https://python.org
        nushell                       # nushell -c for tabular display any shell  https://github.com/nushell/nushell
    # keybinding
        # kanata                     # keybinds                                  https://github.com/jtroo/kanata
    # nix dev
        nixfmt
        nil
    # python dev
        uv                            # `pyenv` but it's actually good
        ruff                          # python linter                             https://github.com/astral-sh/ruff
        # ruff-lsp                      # ruff integration with vscode              https://github.com/astral-sh/ruff-lsp
    # help-systems
        cheat                         # cli cheatsheets                           https://github.com/cheat/cheat
        tldr                          # better man pages                          https://tldr.sh/       
    # git                       # git                                       # git  
        gh                            # github cli                                https://github.com/cli/cli
        git                           # git scm                                   https://git-scm.com
        delta                         # `delta` - git diff                        https://github.com/dandavison/delta
        lazygit                       # TUI git interface                         https://github.com/jesseduffield/lazygit
        commitizen                    # commitizen                                https://github.com/commitizen-tools/commitizen
    
    # general utils
        diffutils                     # `diff` utils                              https://github.com/ogham/diffutils
        direnv                        # per-directory environments                https://github.com/direnv/direnv
        sqlite                        # sqlite                                    https://www.sqlite.org/
        riffdiff                      # provides `riff`, where-in-line diff       https://github.com/walles/riff
    
    
    # file-transfer
        aria2                         # cli download manager                      https://aria2.github.io/
        magic-wormhole-rs             # easy transfer arbitrary files encrypted   https://github.com/magic-wormhole/magic-wormhole.rs
        rsync                         # up hill both ways                         https://linux.die.net/man/1/rsync
    # file-info
        which                         # `which`                                   https://www.gnu.org/software/which/
        file                          # `file` show filetype                      https://darwinsys.com/file
    
    # editors
        neovim                        # text editor                               https://neovim.io/
    # docker
        lazydocker                    # TUI docker interface                      https://github.com/jesseduffield/lazydocker
    # dev
        entr                          # run commands when files change            https://github.com/eradman/entr
        tokei                         # count lines of code                       https://github.com/XAMPPRocky/tokei
        mprocs                        # run multiple commands in parallel         https://github.com/ogham/mprocs
    # bash dev
        shellcheck                    # bash linter                               https://www.shellcheck.net/
        shfmt                         # bash formatter                            https://github.com/mvdan/sh
    # command runners
        mask
        just                          # just                                      https://github.com/casey/just
    # cli-appearance
        vivid                 # LS_COLORS generator                       https://github.com/sharkdp/vivid


    ];
    in
    {
    home.packages = packageList;

    programs.dircolors = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };

    programs.starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
    };

    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
    programs.direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        nix-direnv.enable = true;
    };
    programs.micro = {
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

    programs.broot = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
    };

    programs.tmux = {
        enable = true;
    };

    programs.eza = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
    };

    
    
    
    

    programs.fzf = {
        enable = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        defaultOptions = [
            "--height 40%"
            "--layout=reverse"
            "--border"
            "--inline-info"
            #todo: fix these I think they only work for bash or its expecting `vivid`
            # '' --color 'fg:#${vars.colors.base05}' ''              # Text
            # '' --color 'bg:#''${vars.colors.base00}' ''              # Background
            # '' --color 'preview-fg:#''${vars.colors.base05}' ''      # Preview window text
            # '' --color 'preview-bg:#''${vars.colors.base02}' ''      # Preview window background
            # '' --color 'hl:#''${vars.colors.base0A}' ''              # Highlighted substrings
            # '' --color 'fg+:#''${vars.colors.base0D}' ''             # Text (current line)
            # '' --color 'bg+:#''${vars.colors.base02}' ''             # Background (current line)
            # '' --color 'gutter:#''${vars.colors.base02}' ''          # Gutter on the left (defaults to bg+)
            # '' --color 'hl+:#''${vars.colors.base0E}' ''             # Highlighted substrings (current line)
            # '' --color 'info:#''${vars.colors.base0E}' ''            # Info line (match counters)
            # '' --color 'border:#''${vars.colors.base0D}' ''          # Border around the window (--border and --preview)
            # '' --color 'prompt:#''${vars.colors.base05}' ''          # Prompt
            # '' --color 'pointer:#''${vars.colors.base0E}' ''         # Pointer to the current line
            # '' --color 'marker:#''${vars.colors.base0E}' ''          # Multi-select marker
            # '' --color 'spinner:#''${vars.colors.base0E}' ''         # Streaming input indicator
            # '' --color 'header:#''${vars.colors.base05}' ''          # Header
        ];
    };
    };
    programs.zoxide = {      
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        options                 = [ "--cmd x" ];  # `zi` alias interferes with z-shell/zi
    };
}
