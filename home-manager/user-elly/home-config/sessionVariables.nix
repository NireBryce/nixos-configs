# desc = "elly user session variables";
{ pkgs, ... }:
{
    home.sessionVariables = { 
        EDITOR                  = "micro";
        MICRO_TRUECOLOR         = 1;
        NIXPKGS_ALLOW_UNFREE    = 1;
        PYTHONBREAKPOINT        = "ipdb.set_trace";
        COLORTERM               = "truecolor";
        PAGER                   = "less -R";
        MANPAGER                = "${pkgs.bat}/bin/bat --language man";
        LC_CTYPE                = "en_US.UTF-8";
        LS_COLORS               = "$(${pkgs.vivid}/bin/vivid generate dracula)";  # https://github.com/sharkdp/vivid
        EZA_COLORS              = "$(${pkgs.vivid}/bin/vivid generate dracula)";
        STARSHIP_CONFIG         = "$HOME/.config/starship.toml";
        STARSHIP_CACHE          = "$HOME/.cache/starship";
        PYTHON                  = "PYTHON";
    };
}
