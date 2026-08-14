# Core system-level settings every darwin host in this config wants.
# Ported from macos-old/nire-lysithea-configuration.nix.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.darwin.${moduleName} = {
            # core darwin system settings: primary user, nix management

            # `elly` hardcoded, same as users.users.elly and home.username
            # elsewhere in this tree. nix-darwin needs this for homebrew,
            # launchd user-context activation, and anything else that has to
            # run as a specific logged-in user rather than root.
            system.primaryUser = "elly";

            # nix-darwin manages the nix installation itself, rather than
            # assuming an external installer (e.g. Determinate) owns it.
            nix.enable = true;

            # NOT account creation -- nix-darwin does not create macOS user
            # accounts, only describes an existing one. Without this,
            # `users.users.elly.home` stays at its own default of `null`
            # (modules/users/user.nix: "This defaults to null... if the user
            # has not been created yet"), and home-manager's own
            # nixos/common.nix derives `home.homeDirectory` directly from
            # `config.users.users.${name}.home` -- so home.homeDirectory
            # evaluates to null and fails home-manager's own type check.
            #
            # hm-config.nix already carries `home.homeDirectory = mkDefault
            # "/home/elly"; # Darwin is different` -- correctly anticipating
            # the problem.
            users.users.elly.home = "/Users/elly";
        };
}
