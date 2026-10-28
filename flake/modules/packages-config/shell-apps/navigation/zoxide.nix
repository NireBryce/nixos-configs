# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { 
  # package summary: zoxide -- `cd` that jumps to frequently used directories
  # Zoxide - better `cd`
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    # options                 = [ "--cmd x" ];
  };
};
}
