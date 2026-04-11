{ lib, NAMESPACE_HERE, ... }:
let
    aspect = NAMESPACE_HERE.ASPECT_HERE;
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    
in {
    ${aspect}._.${moduleName} = {
        nixos = {
        
        };
    };
}
