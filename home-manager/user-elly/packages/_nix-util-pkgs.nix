{ pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{

# TODO: make server config


    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
        # todo: fix comma
        # comma                         # `,` run things without installing them    https://github.com/nix-community/comma
        deadnix                       # scan for dead nix code                    https://github.com/astro/deadnix
        manix                         # nix man pages                             https://github.com/nix-community/manix
        # niv                           # like flakes but worse
        nix-diff                      # diff nix code                             https://hackage.haskell.org/package/nix-diff
        nix-du                        # nix-store analysis                        https://github.com/symphorien/nix-du
        nix-health                    # check nix issues                          https://github.com/juspay/nix-health
        nix-init                      # nix packages from URLs                    https://github.com/nix-community/nix-init
        #TODO: nix-index handled in flake.nix, refer to darwin config 
        # nix-index                     # nix store index search                    https://github.com/nix-community/nix-index
        nix-output-monitor            # `nom`                                     https://github.com/maralorn/nix-output-monitor
        nix-tree                      # view dependency graph                     https://hackage.haskell.org/package/nix-tree
        nix-zsh-completions           # nix shell completions                     https://github.com/nix-community/nix-zsh-completions
        nixfmt                        # format nix code                           https://github.com/serokell/nixfmt
        nurl                          # nix fetcher calls from repository URLs    https://github.com/nix-community/nurl
        nvd                           # nix package version diff                  https://gitlab.com/khumba/nvd
        statix                        # antipattern linter                        https://github.com/nerdypepper/statix
    ];
}
