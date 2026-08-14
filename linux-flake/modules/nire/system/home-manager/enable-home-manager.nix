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

                # Without this, HM's activation *aborts* the first time it finds
                # a file it does not already track sitting where it wants to
                # write -- "Existing file '...' is in the way of '...'". Set
                # 2026-08-13, before durandal's first switch onto this branch.
                #
                # It matters here specifically because every host reaching this
                # branch is arriving from *standalone* HM, and the two do not
                # share a profile. Durandal was on standalone generation 319
                # (~/.local/state/nix/profiles/home-manager) with its dotfiles
                # symlinked into a home-manager-files store path. HM reads
                # ~/.local/state/home-manager/gcroots/current-home to work out
                # what it owns, and that gcroot is intact, so the handover
                # should be clean -- but "should" is the whole reason for a
                # backup extension. Anything HM cannot account for gets renamed
                # to <file>.hm-bak instead of failing the switch half-applied,
                # with the system activated and the home not.
                #
                # Cheap to leave on permanently: on a run with no collisions it
                # does nothing at all. If .hm-bak files appear, that is a real
                # finding about untracked state, not noise to be swept up.
                backupFileExtension = "hm-bak";

                # the full path here is `home-manager.users.elly`; the account
                # name is hardcoded, as it is in users.users.elly and
                # home.username
                users.elly = ellyHome;
            };
        };
    }
