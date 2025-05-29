{
    ...
}:
 
{
    programs.kitty = {
        enable  = true;
        extraConfig = ''
            clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask
            kitty_mod ctrl+shift

            map kitty_mod+c copy_to_clipboard
            map cmd+c       copy_or_interrupt

            map kitty_mod+v paste_from_clipboard
            map cmd+v       paste_from_clipboard
        '';
    };
}
