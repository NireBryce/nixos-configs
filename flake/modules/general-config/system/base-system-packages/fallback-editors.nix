# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            # Editors
            vim # failsafe
            nano # backup of a backup, vim is bad on a phone                               https://www.nano-editor.org/
            nanorc # nano syntax highlighting
        ];
    };
}
