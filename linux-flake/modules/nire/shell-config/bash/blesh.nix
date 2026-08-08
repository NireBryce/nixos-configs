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
                bleopt complete_menu_style=desc

                bleopt menu_desc_multicolumn_width=

                # Note: If you would like to combine fzf-completion with bash_completion, you
                # need to load bash_completion earlier than fzf-completion.

                # source ${pkgs.bash-completion}/etc/bash_completion

                _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

                # Set up fzf
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash
            '';
        };
}
