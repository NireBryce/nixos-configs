# The single human account these machines are built for.
#
# GREP NOTE: this replaced hardcoded `users.users.elly` / `home-manager.users.elly`
# / `user = "elly"` throughout the nixos modules. Those literal strings no longer
# appear, so searching for `users.users.elly` will land you here and nowhere
# else. The call sites now read `users.users.${config.nire.primaryUser}`.
#
# Declared as a real NixOS option rather than passed through specialArgs so any
# module can read it without depending on the user module's internals, and so
# `nixos-option nire.primaryUser` works.
#
# Consumers, as of this commit:
#   nire/users/elly.nix            users.users.<user>
#   nire/ssh/ssh.nix               users.users.<user>.openssh.authorizedKeys
#   nire/virtualization/…          users.users.<user>.extraGroups
#   nire/auth-yubikey/yubikey.nix  config.users.users.<user>.home
#   nire/home-manager/…            home-manager.users.<user>
#   nire/wm-jovian/jovian.nix      jovian.steam.user, services.handheld-daemon.user
{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.primary-user ];

    flake.modules.nixos.primary-user = { lib, ... }:
    {
        options.nire.primaryUser = lib.mkOption {
            type        = lib.types.str;
            default     = "elly";
            description = "Account owning the desktop session, Steam and home-manager.";
        };
    };
}
