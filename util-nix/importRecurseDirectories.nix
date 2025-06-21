{ import-tree, ... }:
{
    lib.util.importRecurseDirectories = {importPath}: (import-tree importPath);
}
