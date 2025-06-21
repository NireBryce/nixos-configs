{ import-tree, ... }:
let 
    importRecurseDirectories = {importPath}: (import-tree importPath);
    lib.util = { inherit importRecurseDirectories; };
in

# TODO this can't be the way to write this.  the reference is https://github.com/numtide/flake-utils/blob/main/lib.nix
lib

