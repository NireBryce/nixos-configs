{ config, inputs, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.home-manager ];

    flake.modules.nixos.home-manager =
    {
        imports = [
            inputs.home-manager.nixosModules.home-manager
        ];

        home-manager = {
            # Reuse the system's nixpkgs rather than instantiating a second one.
            # allowUnfree is already set system-wide in nire/nix/nix-settings.
            useGlobalPkgs   = true;
            useUserPackages = true;

            users.elly = config.flake.modules.homeManager.ellyHomeManager;
        };
    };
}
