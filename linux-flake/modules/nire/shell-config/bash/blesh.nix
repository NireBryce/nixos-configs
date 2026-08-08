{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # This module owns .blerc. bash.nix carried a byte-identical copy of it
        # until they were merged here -- home.file.<n>.text is types.lines, so
        # both definitions concatenated and every ble-import below ran twice.
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # bash line editor, allows zsh-like line editor tricks and bindings.
            #
            # There is no `programs.bash.blesh` option -- Home Manager has no blesh
            # module of any kind, so the `programs.bash.blesh.enable = true` that
            # used to be here had never applied. blesh is wired up by hand in
            # bash.nix instead: the package in home.packages, `source ble.sh
            # --attach=none` early in initContent, and `ble-attach` at the end.

            home.file.".blerc".text = ''
                # ─── completion behaviour ────────────────────────────────────
                # Most of the zsh-like behaviour is already ble.sh's default:
                #   complete_auto_complete=1   inline grey suggestion (like zsh-autosuggestions)
                #   complete_menu_complete=1   TAB cycles through candidates
                #   complete_menu_filter=1     typing narrows the open menu
                #   complete_ambiguous=1       ambiguous/partial matching
                #   complete_menu_color=on     coloured candidates
                # so only the gaps are set here.

                # Show the menu without waiting for a TAB, the way zsh-autocomplete
                # does on the zsh side. Off by default in ble.sh.
                bleopt complete_auto_menu=1

                # Candidates with their descriptions alongside, like zsh's
                # completion descriptions.
                bleopt complete_menu_style=desc

                # ─── completion sources ──────────────────────────────────────
                # bash-completion must be imported *before* the fzf integrations,
                # per ble.sh's own note. The contrib integration is the right way
                # in; sourcing etc/bash_completion directly is what the old
                # commented-out line here was reaching for.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/bash-completion.bash

                # nix/nixos/nix-shell completions -- the counterpart to
                # nix-zsh-completions on the zsh side.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/nix-completion.bash

                # ─── fzf ─────────────────────────────────────────────────────
                _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

                # fzf-menu renders the completion menu through fzf, which is the
                # closest equivalent to the zsh config's zsh-fzf-tab.
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-menu.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash
            '';
        };
}
