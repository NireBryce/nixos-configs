{ lib }:
let 
    # Recursively collect all package names under a directory.
    # Files become package names (with .nix stripped).
    # Subdirectories are descended into - they are sub-categories for
    # organizational purposes only and do not appear in the provides keys.
    collectNames = dir:
        lib.concatMap
        ({ name, value }:
            if value == "directory"
            then collectNames (dir + "/${name}")
            else [ (lib.removeSuffix ".nix" name) ])
        (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

in { collectNames = collectNames; }
