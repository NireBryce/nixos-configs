# Host roles.
#
# `flake.modules.<class>.<name>` is a deferredModule, so several files can each
# define the same aggregate and the module system merges them. Feature modules
# therefore opt *themselves* into a role, next to their own definition:
#
#     flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];
#
# which means adding a module is a one-file change rather than also editing
# every host that wants it. This file only declares the hierarchy between the
# roles; membership lives with each module.
{ config, ... }:
{
    flake.modules.nixos.desktop.imports  = [ config.flake.modules.nixos.base ];
    flake.modules.nixos.handheld.imports = [ config.flake.modules.nixos.base ];
}
