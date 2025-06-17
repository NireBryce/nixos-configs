{ 
  self,
  ... 
}: 

let 
# self variable is the root location of the build tree, give or take
_flakeDir           = "${self}";
_systemConfigDir    = "${_flakeDir}/system-config";
_hostName           = "nire-durandal";
_windowManager      = "kde";
_userName           = "elly";

_subModulesList     = [
    "${_systemConfigDir}/users/${_userName}"
    "${_systemConfigDir}/hosts/${_hostName}"
    "${_systemConfigDir}/wm/${_windowManager}"
]; 

in {
    imports = _subModulesList;
    
    networking.hostName = _hostName;
}
