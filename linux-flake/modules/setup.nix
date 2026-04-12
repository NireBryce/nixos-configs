{ den, lib, ... }: 
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
            # Import each file, passing nothing since utilities are self-contained
            (lib.mapAttrs (name: _: import (libDir + "/${name}") {}))
            # Merge all the resulting attrsets into one
            (lib.foldl' lib.mergeAttrs {})
        ];
    
    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    # everywhere it is must take __findFile, 
    # { __findFile, ... }: { includes = [ <nire.nix/all> ]; };
    _module.args.__findFile = den.lib.__findFile;
}
