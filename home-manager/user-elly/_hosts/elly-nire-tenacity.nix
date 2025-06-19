# TODO: merge this and durandal into one config, split out hardware-specific.
#* This defines the nire-durandal host-specific user config for elly
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

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
