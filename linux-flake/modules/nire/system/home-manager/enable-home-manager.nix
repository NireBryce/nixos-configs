# Home Manager, managed from the NixOS side.
#
# Lives under nire/system/ so the `system` category picks it up and durandal gets
# it with everything else. There is no homeConfigurations output and no separate
# home switch: `nh os switch` applies both.
#
# To go back to standalone, see linux-flake/home-manager-standalone.md.
{ config, lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Bound out here, before the module body, on purpose. Inside the body
        # `config` would mean the *NixOS* config, not the flake-parts one, the
        # moment anyone adds an argument list to reach it -- and then
        # `config.flake.modules...` silently stops resolving. Binding it in the
        # let keeps that edit from breaking this.
        ellyHome = config.flake.modules.homeManager.ellyHomeManager;
    in {
        flake.modules.nixos.${moduleName} = {
            imports = [ inputs.home-manager.nixosModules.home-manager ];

            home-manager = {
                # Use the system's nixpkgs rather than a second instantiation.
                # This is what makes HM reject any `nixpkgs.*` option set inside a
                # home module -- allowUnfree has to come from the system, and does,
                # in nire/nix/nix-settings/basic-nix-settings.nix.
                useGlobalPkgs = true;

                # Packages land in /etc/profiles/per-user/<name> instead of a
                # separate ~/.nix-profile, so home.profileDirectory moves too.
                useUserPackages = true;

                # GREP NOTE: `home-manager.users.elly`. The account name is
                # hardcoded here as it is elsewhere on this branch
                # (users.users.elly, home.username); introducing nire.primaryUser
                # is a separate change.
                users.elly = ellyHome;
            };
        };
    }
