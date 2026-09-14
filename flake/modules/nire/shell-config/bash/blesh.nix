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

            # WHY THE PIECES BELOW ARE SHAPED THE WAY THEY ARE. This is the
            # `.nix` editor's copy; `#` inside the `''` string is shell text
            # that ships into ~/.blerc verbatim, so the string keeps only what
            # a reader of the dotfile needs. Full account of all of it, with
            # the upstream bug found along the way:
            # wiki/categories/shell-config/blesh.md.
            #
            #   - `complete_auto_menu` MUST NOT be set. It reads like a boolean
            #     and is an idle DELAY (`until=$((_ble_idle_clock_start +
            #     bleopt_complete_auto_menu))`, lib/core-complete.sh), fired
            #     from ble/widget/self-insert -- ordinary typing. Set to 1 with
            #     fzf-menu imported, fzf took over the terminal on every
            #     keystroke on real hardware. The inline grey suggestion that
            #     makes it feel live is complete_auto_complete, on by default.
            #   - bash-completion imports BEFORE the fzf integrations, per
            #     ble.sh's own note.
            #   - The atuin C-r rebind must be a `-C` callback on the fzf
            #     import, not ble-bind lines in this file: `-d` defers loading
            #     to idle, so fzf-key-bindings lands after .bashrc, after
            #     atuin's readline bind, after ble-attach -- fzf wins by
            #     arriving last, and -C is the only hook that follows it. It
            #     REBINDS rather than unbinds because ble.sh replaces readline
            #     outright, so an unbound key does nothing rather than falling
            #     back. Two -C options, not one with an embedded newline: the
            #     option repeats (`[-C CALLBACK]+`) and each callback stays one
            #     command. If C-r ever goes dead, check that __atuin_history
            #     still takes --keymap-mode.
            #   - C-v is unbound through `blehook ATTACH`, not a top-level
            #     ble-bind: .blerc is sourced by ble/base/load-rcfile, which
            #     runs BEFORE ble-attach calls ble/decode/attach -- the step
            #     that lazily loads keymap/emacs.sh and installs C-v's default
            #     quoted-insert binding. A plain call here would be overwritten.
            #     Read from ble.sh's source, not verified against a live menu.
            home.file.".blerc".text = ''
                # ─── completion behaviour ────────────────────────────────────
                # ble.sh already defaults to most of the zsh-like behaviour
                # (inline suggestion, TAB menu, narrowing, ambiguous matching,
                # coloured candidates); only the gaps are set here.
                #
                # NOTE: do not set complete_auto_menu -- it is an idle delay,
                # not a boolean, and =1 opens the fzf menu on every keystroke.

                # Candidates with their descriptions alongside, like zsh's
                # completion descriptions.
                bleopt complete_menu_style=desc

                # ─── completion sources ──────────────────────────────────────
                # bash-completion first: the fzf integrations below expect it.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/bash-completion.bash

                # nix/nixos/nix-shell completions -- the counterpart to
                # nix-zsh-completions on the zsh side.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/nix-completion.bash

                # Real descriptions for carapace candidates, which its own
                # bash completer cannot emit. See carapace-desc.bash.
                ble-import -d ${carapaceDescBash}

                # ─── fzf ─────────────────────────────────────────────────────
                _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

                # The completion menu through fzf: the zsh-fzf-tab equivalent.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-menu.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash

                # Ctrl-R stays atuin's; fzf-key-bindings keeps Ctrl-T, Alt-C.
                # The -C callbacks are load-bearing -- see blesh.nix.
                ble-import -d \
                    -C 'ble-bind -m emacs   -x C-r "__atuin_history --keymap-mode=emacs"' \
                    -C 'ble-bind -m vi_imap -x C-r "__atuin_history --keymap-mode=vim-insert"' \
                    ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash

                # ─── keybindings ─────────────────────────────────────────────
                # C-v is quoted-insert by default in both insert keymaps, and
                # muscle-memory "paste" hits it constantly. Unbound via ATTACH
                # because .blerc is sourced before the keymaps load.
                blehook ATTACH+='ble-bind -m emacs -f C-v -; ble-bind -m vi_imap -f C-v -'
            '';
        };
}
