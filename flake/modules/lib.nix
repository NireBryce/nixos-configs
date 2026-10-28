# `flake.lib`: small pure helpers shared by modules. Modules reach it as
# `inputs.self.lib` (a module file may be a function of `lib`/`inputs`), a plain
# flake-parts module reaches it as `config.flake.lib`.
#
# Loaded as a plain flake-parts module, not a module file: it returns no class
# key (wiki/config-structure/module-files.md). The helpers themselves live in
# `_lib/`, one file per topic -- `_` paths are skipped by the module tree, so
# those files are not modules and name no class. Each is `{ lib }: { ... }` and
# pure: it takes the values it needs as arguments, so none of it forces a host's
# evaluation.
#
# `flake.lib` is typed `raw`, which allows one definition. A topic goes in
# `_lib/<topic>.nix` and an entry below; a second `flake.lib = ...` elsewhere
# would be a conflict, not a merge.
{ lib, ... }:
{
    flake.lib = {
        persist = import ./_lib/persist.nix { inherit lib; };
        fleet   = import ./_lib/fleet.nix   { inherit lib; };
        nixpkgs = import ./_lib/nixpkgs.nix { inherit lib; };
    };
}
