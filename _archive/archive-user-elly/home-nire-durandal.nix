#* This defines the nire-durandal host-specific user config for elly
{ 
    self,
    ... 
}:

let 
_flakeDir       =       "${self}"; # the root of the flake
_userName       =       "elly";
_userHome       =       "/home/${_userName}";
_hmUserDir      =       "${_flakeDir}/home-manager/user-${_userName}";
_windowManager  =       "kde";


subConfigList = [
    "${_hmUserDir}/nix-settings"
    "${_hmUserDir}/hm-settings"
    "${_hmUserDir}/dotfiles"
    "${_hmUserDir}/git"
    "${_hmUserDir}/window-manager/${_windowManager}"

    "${_hmUserDir}/packages/"
    "${_flakeDir}/home-manager/plasma-manager"

];
in 
{
    imports = subConfigList;

    home.username            = _userName;
    home.homeDirectory       = _userHome;
}


