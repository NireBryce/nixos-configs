# `nix flake check` should actually check something.
#
# Everything that broke this branch was an evaluation error, and every one of
# them hid behind the previous: a raw `perSystem` wrapper, then bare strings in
# `imports`, then a duplicate dynamic attribute, then a nixos module full of
# home-manager options. Evaluating a cheap attribute proves nothing --
# `networking.hostName` resolved happily through most of that. Forcing each
# host's toplevel derivation is what catches the class, and it builds nothing.
#
# This file sits at the top of modules/ rather than in a category directory, so
# dirsAsCategory does not collect it; that only walks subdirectories.
{ config, lib, ... }:
{
    perSystem = { system, pkgs, ... }:
    let
        hostsForThisSystem = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system)
            config.flake.nixosConfigurations;

        hostChecks = lib.mapAttrs'
            (name: host: lib.nameValuePair "nixos-${name}" host.config.system.build.toplevel)
            hostsForThisSystem;

        # The home config is only reachable through the host that owns it, so a
        # check on the toplevel does force it -- but naming it separately makes a
        # home-only breakage say so instead of failing as "the host".
        #
        # Filtered to hosts that actually have home-manager, same gate
        # invariants.nix's usesHomeManager uses and for the same reason:
        # nire-installer never imports enable-home-manager.nix, has no `elly`
        # user, and `host.config.home-manager` is a missing attribute there
        # rather than an empty one.
        homeChecks = lib.mapAttrs'
            (name: host: lib.nameValuePair "home-${name}"
                host.config.home-manager.users.elly.home.activationPackage)
            (lib.filterAttrs (_: host: host.config ? home-manager) hostsForThisSystem);
    in
    {
        checks = hostChecks // homeChecks // {
            # Static, so it is the one real check that also runs on darwin -- the
            # host checks are filtered by system and have never executed here.
            #
            # Catches the two failures this layout cannot report by evaluating: a
            # module whose filename collides with a category name (they merge
            # silently), and a module no aggregate can reach (valid, evaluates,
            # installs nothing).
            module-tree = pkgs.runCommand "module-tree-check"
                { nativeBuildInputs = [ pkgs.python3 ]; }
                ''
                    if ! python3 ${../scripts/modules.py} check ${./.} > "$out"; then
                        cat "$out" >&2
                        exit 1
                    fi
                    cat "$out"
                '';
        };
    };
}
