# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { 
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
