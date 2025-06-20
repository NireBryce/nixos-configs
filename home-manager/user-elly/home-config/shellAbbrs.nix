# desc = "";
{ ... }:
{
    # ! WARN: unsure how global aliases work here
    # for now they're declared in the zsh config but that's 
    #    not declarative -- it saves them to abbr even if
    #    you remove them from the zsh config
    programs.zsh.zsh-abbr.abbreviations = {
        "abbr remove"           = "abbr erase";
        "abbr rm"               = "abbr erase";
        "cs-zsh-bindings"       = "bindkey";
        "cs-zsh-highlighting"          = "fast-theme sv-orple";
        "wh"                    = "wormhole";
        "whence"                = "type -a";
        "zsh-keymap"            = "bindkey";
    };    
}
