{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    {  ... }:

    {
        programs.zoxide = {      
            enable                  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
            enableFishIntegration   = true;
            options                 = [ "--cmd x" ];  # TODO: remove when you remove zi or zsh
        };    
    };
}
