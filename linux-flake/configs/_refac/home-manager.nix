{ inputs, config, ...}:
let
    home-manager-config =
    { lib, ... }:
    {
        home-manager = {
            verbose = true;
            useUserPackages = true;
            useGlobalPkgs = true;
            backupFileExtension = "backup";
            backupCommand = "cp";
            overwriteBackup = true;
        };
    };
in
{
    flake.modules.nixos.home-manager = {
        imports = [
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
        ];
    };
    flake.modules.darwin.home-manager = {
        imports = [
            inputs.home-manager.nixosModules.home-manager
            home-manager-config
        ];
    };
}
