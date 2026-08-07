{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.elly-shell-bash-blesh ];

    flake.modules.homeManager.elly-shell-bash-blesh =
{ pkgs, ... }:

{
    # bash line editor, allows zsh-like line editor tricks and bindings.
    # This module owns blesh and .blerc; shell-bash/bash.nix only attaches it.
    home.packages = with pkgs; [
        blesh
    ];

    home.file.".blerc".text = ''
        # ─── completion behaviour ────────────────────────────────────────────
        # Most of the zsh-like behaviour is already ble.sh's default:
        #   complete_auto_complete=1   inline grey suggestion (zsh-autosuggestions)
        #   complete_menu_complete=1   TAB cycles through candidates
        #   complete_menu_filter=1     typing narrows the open menu
        #   complete_ambiguous=1       ambiguous/partial matching
        #   complete_menu_color=on     coloured candidates
        # so only the gaps are set here.

        # Show the menu without waiting for a TAB, the way zsh-autocomplete does.
        # This is off by default in ble.sh.
        bleopt complete_auto_menu=1

        # Candidates with their descriptions alongside, like zsh's completion
        # descriptions. menu_desc_multicolumn_width is left at its default (65);
        # it used to be overridden to empty here, which disabled the column layout.
        bleopt complete_menu_style=desc

        # ─── completion sources ──────────────────────────────────────────────
        # bash-completion must be imported *before* the fzf integrations, per
        # ble.sh's own note. Using the contrib integration rather than sourcing
        # etc/bash_completion directly, which is what the old commented-out line
        # here was trying to do.
        ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/bash-completion.bash

        # nix/nixos/nix-shell completions, the counterpart to nix-zsh-completions
        # on the zsh side.
        ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/nix-completion.bash

        # ─── fzf ─────────────────────────────────────────────────────────────
        _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

        # fzf-menu renders the completion menu through fzf. This is the closest
        # equivalent to zsh-fzf-tab, which the zsh config uses.
        ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-menu.bash
        ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash
        ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash
    '';
};
}
