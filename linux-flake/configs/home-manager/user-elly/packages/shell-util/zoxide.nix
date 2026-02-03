# desc = "";
{ flake.modules.homeManager.packages.shellUtil.zoxide =
{  ... }:

{
    programs.zoxide = {      
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        # options                 = [ "--cmd x" ];  # TODO: remove when you remove zi or zsh
    };    
}

;}
