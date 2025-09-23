{ 
  self,
  ... 
}: 
  
let 
# self variable is the root location of the build tree, give or take
_flakeDir           = self;
_systemConfigDir    = "${_flakeDir}/system-config";
_hostName           = "nire-tenacity";
_windowManager      = "gaming-handheld";
_userName           = "elly";
_submodulesList = [ 

    "${_systemConfigDir}/users/${_userName}"
    "${_systemConfigDir}/hosts/${_hostName}"
    "${_systemConfigDir}/wm/${_windowManager}"

];

in {
    imports = _submodulesList;
    networking.hostName = _hostName;


}

# TODO: remove me
