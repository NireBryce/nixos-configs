# desc = "bash line editor, allows zsh-like line editor tricks and bindings";
{ pkgs, ... }:
let packageList = with pkgs; [
    blesh
];
in
{
    home.packages = packageList;
    home.file.".blerc".text = ''
        bleopt complete_menu_style=desc

        bleopt menu_desc_multicolumn_width=0

        ble-import -d integration/fzf-menu

        # If needed. See above for details:
        #_ble_contrib_fzf_base=/path/to/fzf-directory

        _ble_contrib_fzf_git_config=key-binding:sabbrev:arpeggio
        ble-import -d integration/fzf-git

        # If ble/contrib/integration/fzf cannot find the fzf directory, please set the
        # following variable "_ble_contrib_fzf_base" manually.  The value
        # "/path/to/fzf-directory" should be replaced by a path to the fzf directory
        # such as "$HOME/.fzf" or "/usr/share/fzf" that contain
        # "shell/{completion,key-bindings}.bash" or "{completion,key-bindings}.bash".

        _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf


        # Note: If you would like to combine fzf-completion with bash_completion, you
        # need to load bash_completion earlier than fzf-completion.

        source ${pkgs.bash-completion}/etc/bash_completion


        # Set up fzf
        ble-import -d integration/fzf-completion
        ble-import -d integration/fzf-key-bindings


    '';
}
