{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # This module owns .blerc. bash.nix carried a byte-identical copy of it
        # until they were merged here -- home.file.<n>.text is types.lines, so
        # both definitions concatenated and every ble-import below ran twice.
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            let
                # A real file rather than inlined into the .blerc string
                # below on purpose: this script is full of bash `${...}`
                # parameter expansions, and every one of those would need
                # escaping as ''${...} inside a Nix '' string. Reading it
                # from disk means its content is never touched by Nix's
                # string interpolation at all.
                carapaceDescBash = pkgs.writeText "carapace-desc.bash"
                    (builtins.readFile ./carapace-desc.bash);
            in {
            # bash line editor, allows zsh-like line editor tricks and bindings.
            #
            # There is no `programs.bash.blesh` option -- Home Manager has no
            # blesh module of any kind, so the `programs.bash.blesh.enable =
            # true` that used to be here had never applied. blesh is wired up
            # by hand in bash.nix instead: the package in home.packages,
            # `source ble.sh --attach=none` early in initContent, and
            # `ble-attach` at the end.

            home.file.".blerc".text = ''
                # ─── completion behaviour ────────────────────────────────────
                # Most of the zsh-like behaviour is already ble.sh's default:
                #   complete_auto_complete=1   inline grey suggestion (like zsh-autosuggestions)
                #   complete_menu_complete=1   TAB cycles through candidates
                #   complete_menu_filter=1     typing narrows the open menu
                #   complete_ambiguous=1       ambiguous/partial matching
                #   complete_menu_color=on     coloured candidates
                # so only the gaps are set here.

                # complete_auto_menu is NOT set, and must not be set to 1.
                #
                # It reads like a boolean and is an idle *delay*. ble.sh uses it
                # as `until=$((_ble_idle_clock_start + bleopt_complete_auto_menu))`
                # (lib/core-complete.sh), and the surrounding case fires on
                # ble/widget/self-insert -- ordinary typing. So `=1` means "open
                # the menu one tick after every character", and with
                # fzf-menu.bash imported below, that menu is fzf. This file did
                # set it to 1, meaning "on", the way zsh-autocomplete works on
                # the zsh side; on the hardware fzf took over the terminal on
                # every keystroke, as though TAB were held down. Unset, the
                # menu is TAB-driven -- the zsh-fzf-tab behaviour, which is
                # what pairing it with fzf-menu wanted in the first place.
                #
                # The inline grey suggestion that made zsh-autocomplete feel
                # live is a different option, complete_auto_complete, already
                # on by default.
                #
                # If a delay is ever genuinely wanted, it is a number of
                # milliseconds and wants to be in the hundreds or thousands --
                # and check it against fzf-menu, which renders full-screen.

                # Candidates with their descriptions alongside, like zsh's
                # completion descriptions.
                bleopt complete_menu_style=desc

                # ─── completion sources ──────────────────────────────────────
                # bash-completion must be imported *before* the fzf integrations,
                # per ble.sh's own note. The contrib integration is the right way
                # in (the old commented-out line here sourced etc/bash_completion
                # directly).
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/bash-completion.bash

                # nix/nixos/nix-shell completions -- the counterpart to
                # nix-zsh-completions on the zsh side.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/nix-completion.bash

                # carapace's own bash completer only emits plain candidate
                # words (bash's COMPREPLY has no description slot); this
                # advises it to pull real descriptions from a separate
                # carapace mode and feed them through ble.sh's own candidate
                # list instead. See carapace-desc.bash for the full mechanism
                # and its 2026-08-22 caveats -- checked against ble.sh's
                # source, not yet against the live menu.
                ble-import -d ${carapaceDescBash}

                # ─── fzf ─────────────────────────────────────────────────────
                _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

                # fzf-menu renders the completion menu through fzf, which is the
                # closest equivalent to the zsh config's zsh-fzf-tab.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-menu.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash

                # Ctrl-R is atuin's. fzf-key-bindings keeps Ctrl-T and Alt-C.
                #
                # This has to be a -C callback on the import, not a couple of
                # ble-bind lines further down this file, because -d means
                # "register for later loading in idle time" -- ble.sh's own
                # --help -- so the module lands *after* everything in .bashrc,
                # including ble-attach. The order actually is:
                #
                #   .bashrc:35  ble.sh sourced, this file registers the deferred import
                #   .bashrc:49  atuin binds C-r, via readline `bind -m`
                #   .bashrc:75  ble-attach imports atuin's readline binding
                #   idle        fzf-key-bindings loads and overwrites C-r
                #
                # fzf wins by arriving last. -C runs "when all of SCRIPTFILEs
                # are loaded", so it is the only hook that reliably follows it.
                #
                # It rebinds rather than unbinds: ble.sh replaces readline
                # outright, so a key with no entry in its keymap does nothing --
                # removing fzf's binding would leave Ctrl-R dead rather than
                # falling back to atuin's.
                #
                # The commands are what atuin's own atuin-bind maps
                # atuin-search-emacs and atuin-search-viins to; atuin binds
                # through readline rather than ble-bind, so there is no widget
                # name to reuse. If Ctrl-R ever starts doing nothing, check
                # that __atuin_history still takes --keymap-mode.
                # Two -C options rather than one carrying an embedded newline:
                # ble.sh's usage line is `[-C CALLBACK|--callback=CALLBACK]+`,
                # so the option repeats, and each callback stays a single
                # command.
                ble-import -d \
                    -C 'ble-bind -m emacs   -x C-r "__atuin_history --keymap-mode=emacs"' \
                    -C 'ble-bind -m vi_imap -x C-r "__atuin_history --keymap-mode=vim-insert"' \
                    ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash
            '';
        };
}
