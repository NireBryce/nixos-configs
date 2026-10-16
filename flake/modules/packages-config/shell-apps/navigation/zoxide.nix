# Module file: named after this file; why it looks this way: wiki/module-files.md
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
