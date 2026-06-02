{ 
    perSystem = {lib, pkgs,...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "bitwarden - password manager https://bitwarden.com/";
            home.packages = with pkgs; [
                bitwarden-desktop
            ];
        };
    };
}
