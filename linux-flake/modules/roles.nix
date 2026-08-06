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
#
# The same applies to `flake.modules.homeManager.ellyHomeManager`, which has no
# declaration of its own: each Home Manager module opts into it the same way.
# That replaced an aggregator that imported *every* homeManager module via
#   builtins.attrValues (builtins.removeAttrs self.modules.homeManager [ ... ])
# and needed a growing exclusion list to avoid importing itself.
{ config, ... }:
{
    flake.modules.nixos.desktop.imports  = [ config.flake.modules.nixos.base ];
    flake.modules.nixos.handheld.imports = [ config.flake.modules.nixos.base ];
}
