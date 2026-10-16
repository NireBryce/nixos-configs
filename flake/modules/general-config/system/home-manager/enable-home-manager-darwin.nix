# Module file: named after this file; why it looks this way: wiki/module-files.md
# Home Manager, managed from the darwin side. The darwin counterpart to
# enable-home-manager.nix, in the same file for the same reason -- see that
# file's own header. Lives here rather than under lysithea's own host
# directory because it is genuinely generic to any darwin host, not specific
# to this one; a second Mac would want it too.
#
# home-manager's own nix-darwin/default.nix is `imports = [ ../nixos/common.nix
# ];` -- the same useGlobalPkgs/useUserPackages/users option declarations the
# NixOS side uses, just with launchctl-based activation instead of a systemd
# unit. So this is the NixOS module's reasoning, unchanged, wired to the
# darwin-side integration module instead.
{ inputs, ... }:
{
    # Handed in the same way as in enable-home-manager.nix: listed in
    # `enables`, received as `enabled.homeManager.elly-home-manager`.
    #
    # The SAME aggregate the NixOS hosts use, deliberately -- not a
    # lysithea-specific bundle. Whatever in it does not evaluate on
    # aarch64-darwin needs excluding at the source (the category, or the
    # one module), not forked here into a second copy of the tree.
    enables.homeManager = [ "elly-home-manager" ];

    darwin = { enabled, ... }: {
        imports = [ inputs.home-manager.darwinModules.home-manager ];

        home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.elly = enabled.homeManager.elly-home-manager;
        };
    };
}
