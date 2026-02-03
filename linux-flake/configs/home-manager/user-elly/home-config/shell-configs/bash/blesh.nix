# desc = "bash line editor, allows zsh-like line editor tricks and bindings";
{ flake.modules.homeManager.common.shells.bash =
{ pkgs, ... }:
let packageList = with pkgs; [
    blesh
];
in
{
    home.packages = packageList;
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

}#
