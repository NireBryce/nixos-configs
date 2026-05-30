{ 
    perSystem = {lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # todo: shouldn't this be a service?
            programs.kdeconnect = {
                enable = true; # kde connect
            };
        };
    };
}
