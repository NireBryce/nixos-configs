{ import-tree, home-manager,... }:
let
    home-manager-config =
    { ... }:
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
            home-manager.nixosModules.home-manager
            (import-tree ./configs/home-manager/user-elly)
        ];
    };
    flake.modules.darwin.home-manager = {
        imports = [
            home-manager.darwinModules.home-manager
            (import-tree ./configs/home-manager/user-elly)
        ];
    };
}
