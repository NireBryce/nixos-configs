{
    ...
}:
 
{
    # "smarter `cd` https://github.com/ajeetdsouza/zoxide";
    programs.zoxide = {      
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        options                 = [ "--cmd x" ];  # `zi` alias interferes with z-shell/zi
    };

}
