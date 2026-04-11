# Claude co-written magic, my nix is not deep enough here even though I can follow it.
# 
# modules/packages/<subcategory>/dirBasedProvides.nix
#
# Automatically builds subcategory aspects for this category from the
# directory structure. The category name is derived from the folder name
# so this file can be copied to any category directory without changes.
#
# Expected structure:
#   development/
#     packages.nix        ← this file
#     scm/
#       git.nix           → nirePackages.development._.scm
#       gh.nix            → nirePackages.development._.scm
#     editors/
#       helix.nix         → nirePackages.development._.editors
#
# Produces:
#   <nirePackages.development>         all packages in this category
#   <nirePackages.development/scm>     all packages under scm/
#   <nirePackages.development/editors> all packages under editors/

{ lib, nirePackages, ... }:
let
    root     = dirOf __curPos.file;
    category = baseNameOf root;

    onlyDirs  = lib.filterAttrs (_: t: t == "directory");
    onlyFiles = lib.filterAttrs (_: t: t == "regular");
    stripNix  = name: lib.removeSuffix ".nix" name;

    # Subcategories are directories at this level
    subcategories = onlyDirs (builtins.readDir root);

    # Package names within a subcategory
    packagesOf = sub:
      lib.mapAttrsToList (name: _: stripNix name)
        (onlyFiles (builtins.readDir (root + "/${sub}")));

    # All package names across all subcategories
    allPackages = lib.concatMap packagesOf (lib.attrNames subcategories);
in {
    nirePackages.${category} = {
      # <nirePackages.category> pulls in everything in this category
      includes = map (n: nirePackages.packages._.${n}) allPackages;

      # <nirePackages.development/subcategory> pulls in just that subcategory
      _ = lib.mapAttrs (sub: _: {
        includes = map (n: nirePackages.packages._.${n}) (packagesOf sub);
      }) subcategories;
    };
}
