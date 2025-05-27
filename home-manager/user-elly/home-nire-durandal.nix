#* This defines the nire-durandal host-specific user config for elly
{ 
    self,
    ... 
}:

let 
_flakeDir       =       self; # the root of the flake
_userName       =       "elly";
_userHome       =       "/home/${_userName}";
_hmUserDir      =       "${_flakeDir}/home-manager/user-${_userName}";
_windowManager  =       "kde";


subConfigList = [
    "${_hmUserDir}/nix-settings"
    "${_hmUserDir}/hm-settings"
    "${_hmUserDir}/dotfiles"
    "${_hmUserDir}/git"
    "${_hmUserDir}/shell"
    "${_hmUserDir}/window-manager/${_windowManager}.nix"

    "${_hmUserDir}/packages/_general-cli-pkgs.nix"
    "${_hmUserDir}/packages/_dev-pkgs.nix"
    "${_hmUserDir}/packages/_nix-util-pkgs.nix"
    "${_hmUserDir}/packages/_linux-cli-pkgs.nix"
    "${_hmUserDir}/packages/_linux-gui-pkgs.nix"
    "${_flakeDir}/home-manager/plasma-manager"
];
in 
{
    imports = subConfigList;

    home.username            = _userName;
    home.homeDirectory       = _userHome;
}


