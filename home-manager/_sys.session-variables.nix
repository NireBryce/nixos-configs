{ ... }:
{
  home.sessionVariables = { 
    EDITOR = "micro";
    MICRO_TRUECOLOR = 1;
    NIXPKGS_ALLOW_UNFREE = 1;
    PYTHONBREAKPOINT = "ipdb.set_trace";
    COLORTERM="truecolor";
    PAGER="less -R";
    MANPAGER="bat --language man";
    LC_CTYPE="en_US.UTF-8";
    LS_COLORS="$(vivid generate dracula)";          # https://github.com/sharkdp/vivid
    EZA_COLORS="$(vivid generate dracula)";         

  };
}


# # For LS_COLORS customization options run this in shell:
# for theme in $(vivid themes); do
#     echo "Theme: $theme"
#     LS_COLORS=$(vivid generate $theme)
#     ls
#     echo
# done
