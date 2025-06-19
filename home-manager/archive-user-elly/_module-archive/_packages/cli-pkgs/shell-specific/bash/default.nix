{
    pkgs,
    ...
}:
 
{
    imports = [
        
    ];
    home.packages = with pkgs;[
        # inshellisense                 # intellisense type shell complete          https://github.com/microsoft/inshellisense
        blesh                         # zsh line editor tricks for bash           https://github.com/akinomyoga/ble.sh
        bash-completion               # bash complete                             https://github.com/scop/bash-completion
    ];
}
