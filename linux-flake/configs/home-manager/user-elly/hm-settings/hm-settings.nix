{ flake.modules.homeManager.hmSettings =
{ import-tree, ... }:
{ 
    home.stateVersion        = "22.11"; 
    home.username            = "elly";
    home.homeDirectory       = "/home/elly";
    imports = [ 
        (import-tree ./configs/home-manager/user-elly) 
    ];
}
;}
