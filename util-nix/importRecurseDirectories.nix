{ import-tree }:
let
    importRecurseDirectories = importPath: (import-tree importPath);
in
{
    lib.util.importRecurseDirectories = importRecurseDirectories;
}
