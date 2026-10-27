# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Home Manager, managed from the NixOS side.
#
# Lives under general-config/system/ so the `system` category picks it up and durandal gets
# it with everything else. There is no homeConfigurations output and no separate
# home switch: `nh os switch` applies both.
#
# To go back to standalone, see flake/doc/trailhead-home-manager-standalone.md.
{ inputs, ... }:
{
    # The Home Manager aggregate arrives as `enabled.homeManager.elly-home-manager`:
    # dirs-as-categories resolves the names listed in `enables` and hands this
    # module exactly those. It used to be bound in a `let` from the flake-parts
    # `config` (`config.flake.modules.homeManager.ellyHomeManager`), out of the
    # module body on purpose, because inside the body `config` is the NixOS
    # one and the reference would silently stop resolving. With `enabled`
    # there is no outer `config` here to confuse it with.
    enables.homeManager = [ "elly-home-manager" ];

    nixos = { enabled, ... }: {
        imports = [ inputs.home-manager.nixosModules.home-manager ];

        home-manager = {
            # Use the system's nixpkgs rather than a second instantiation.
            # This is what makes HM reject any `nixpkgs.*` option set inside a
            # home module -- allowUnfree has to come from the system, and does,
            # in general-config/nix/nix-settings/basic-nix-settings.nix.
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
            users.elly = enabled.homeManager.elly-home-manager;
        };
    };
}
