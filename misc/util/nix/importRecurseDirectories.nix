{ import-tree, ... }:
let
    importRecurseDirectories = {importPath}: (import-tree importPath);
in
{
    lib.util.importRecurseDirectories = importRecurseDirectories;
}

# figure out a better way to define custom library functions
