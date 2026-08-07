{ config, inputs, ... }:
let
    # Bound out here on purpose. The inner module below takes the NixOS `config`
    # so it can read config.nire.primaryUser, which shadows this file's
    # flake-parts `config` -- so config.flake.modules.* has to be resolved
    # before that shadowing happens.
    ellyHome = config.flake.modules.homeManager.ellyHomeManager;
in
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.home-manager ];

    flake.modules.nixos.home-manager =
    { config, ... }:
    {
        imports = [
            inputs.home-manager.nixosModules.home-manager
        ];

        home-manager = {
            # Reuse the system's nixpkgs rather than instantiating a second one.
            # allowUnfree is already set system-wide in nire/nix/nix-settings.
            useGlobalPkgs   = true;
            useUserPackages = true;

            users.${config.nire.primaryUser} = ellyHome;
        };
    };
}
