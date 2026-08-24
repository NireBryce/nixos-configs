{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            home.shellAliases = { 
                # for in-place functions in aliases refer to:  https://stackoverflow.com/questions/34340575/zsh-alias-with-parameter
                lcd                     = ''f() { cd $1 && ls -lah };f'';               
                cdls                    = ''f() { cd $1 && ls -lah };f'';               
                ll                      = "ls -l";
                cp                      = "cp -i";    # Confirm before overwriting something
                exa                     = "${pkgs.eza}/bin/eza --icons=always"; # exa back compat for tools
                # ls                      = "${pkgs.eza}/bin/eza --icons=always --header --group-directories-first --hyperlink";
                # gsa                     = "${pkgs.git}/bin/git stash push";
                img-cat                 = "${pkgs.kitty}/bin/kitty +kitten icat";
                kssh                    = "${pkgs.kitty}/bin/kitty +kitten ssh";
            }
            # Launchers for the two GUI apps that homebrew owns on lysithea
            # and nix owns everywhere else.
            #
            # This module is part of ellyHomeManager, which every host shares
            # verbatim, so these have to be guarded -- on the four Linux hosts
            # `discord` and `google-chrome` already ARE the binaries, and an
            # unguarded alias would shadow them with an `open` that does not
            # exist there. Read the test the same way discord.nix and
            # chrome.nix read theirs: "on darwin, homebrew.nix owns this
            # app", NOT "Linux-only".
            #
            # Why they need aliases at all: a homebrew cask with no `binary`
            # stanza installs only a `.app` bundle and puts nothing on PATH.
            # Both apps ARE installed on lysithea -- as
            # `/Applications/Discord.app` and `/Applications/Google
            # Chrome.app` -- they just stopped being commands.
            #
            # They were commands, briefly, and losing them was a side effect
            # nobody intended:
            #
            #   2026-08-11  6568e348 wires lysithea into ellyHomeManager.
            #               discord.nix and chrome.nix were unguarded then,
            #               so pkgs.discord and pkgs.google-chrome landed on
            #               the Mac. Generations 52-54 have `Discord`,
            #               `google-chrome` and `google-chrome-stable` in
            #               /etc/profiles/per-user/elly/bin.
            #   2026-08-13  b0845be6 adds both guards, dropping the two apps
            #               as unfree duplicates of casks already installed.
            #               Correct on its own terms -- unfree means never on
            #               cache.nixos.org, so every darwin build refetched
            #               them from upstream, the shape that failed a whole
            #               build with a GitHub 503 on obsidian. Its
            #               verification says "lysithea still evaluates, with
            #               discord/google-chrome gone", which was true and
            #               did not notice the commands went too.
            #   2026-08-24  the next darwin switch, eleven days later, is the
            #               first to actually apply it. Generation 55 is
            #               where the commands disappear.
            #
            # Note the nix binary on darwin was `Discord`, capital D, so
            # lowercase `discord` never worked on lysithea even in that
            # window -- typing it produced zsh's `correct 'discord' to
            # 'Discord'` prompt. Reverting the guards would not have fixed
            # that; these aliases are lowercase deliberately.
            // lib.optionalAttrs pkgs.stdenv.isDarwin {
                discord                 = "open -a Discord";
                google-chrome           = "open -a 'Google Chrome'";
            };
            home.sessionVariables = { 
                EDITOR                  = "micro";
                MICRO_TRUECOLOR         = 1;
                NIXPKGS_ALLOW_UNFREE    = 1;
                PYTHONBREAKPOINT        = "ipdb.set_trace";
                COLORTERM               = "truecolor";
                PAGER                   = "less -R";
                MANPAGER                = "${pkgs.bat}/bin/bat --language man";
                LC_CTYPE                = "en_US.UTF-8";
                LS_COLORS               = "$(${pkgs.vivid}/bin/vivid generate dracula)";  # https://github.com/sharkdp/vivid
                EZA_COLORS              = "$(${pkgs.vivid}/bin/vivid generate dracula)";
                # STARSHIP_CONFIG         = "$HOME/.config/starship.toml";
                # STARSHIP_CACHE          = "$HOME/.cache/starship";
                PYTHON                  = "PYTHON";
            };
            home.sessionPath = [ 
                "/usr/local"
                "/usr/bin"
                "$HOME/bin"
                "$HOME/.local/bin"
                "$HOME/.nix-profile/bin"
                "$HOME/.cargo/bin"
            ];
        };
}
