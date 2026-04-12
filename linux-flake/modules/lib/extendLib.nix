# Extends the lib module argument with all utility functions defined
# under modules/lib/. Any .nix file placed there is automatically
# picked up and its exported functions merged into lib.
#
# Usage in any module:
#   { lib, ... }: let
#     namespaceName = lib.findNamespaceUp (builtins.dirOf __curPos.file);
#   in { ... }

{ lib, ... }:
{
  
  _module.args.lib = lib.extend (_: _:
    lib.pipe (builtins.readDir ./.) [
      # Only pick up .nix files, ignore directories
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
      # Import each file, passing lib in case utilities need it
      (lib.mapAttrs (name: _: import ./lib/${name} { inherit lib; }))
      # Merge all the resulting attrsets into one
      (lib.foldl' lib.mergeAttrs {})
    ]
  );
}
