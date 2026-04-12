{ lib, ... }: 
let
    libDir = dirOf __curPos.file + "/_lib";
in 
{
    # Sets _module.args.nireLib to all utility functions defined under modules/_lib/.
    # Any .nix file placed there is automatically picked up and its exported
    # functions merged into nireLib.
    #
    # Usage in any module:
    #   { lib, nireLib, ... }: let
    #     namespaceName = nireLib.findNamespaceUp (dirOf __curPos.file);
    #   in { ... }
    _module.args.nireLib =
        lib.pipe (builtins.readDir libDir) [
            # Only pick up .nix files, ignore directories
            (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
            # Import each file
            (lib.mapAttrs (name: _: import (libDir + "/${name}") {}))
            # Convert to list of attrsets and merge into one
            (lib.attrValues)
            (lib.foldl' lib.mergeAttrs {})
        ];
}
