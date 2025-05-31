{ 
    pkgs,
    ... 
}: 
{
    imports = [
        
    ];
        home.packages = with pkgs;[ 
        cheat                         # cli cheatsheets                           https://github.com/cheat/cheat
        tldr                          # better man pages                          https://tldr.sh/       
    ];
}





