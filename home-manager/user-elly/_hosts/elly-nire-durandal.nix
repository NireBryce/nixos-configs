{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { import-tree, ... }:


    let 
    _userName       =       "elly";
    _userHome       =       "/home/${_userName}";
    _windowManager  =       "kde";

    in 
    {
        imports = [
            (import-tree "../../window-manager/${_windowManager}")
            (import-tree "../../plasma-manager")
            (import-tree "../home-config")
            (import-tree "../hm-settings")
            (import-tree "../.")
        ];

        home.username            = _userName;
        home.homeDirectory       = _userHome;
    };

}
