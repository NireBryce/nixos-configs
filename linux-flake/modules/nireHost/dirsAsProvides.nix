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
#   <nireHosts.durandal>            all submodules in this category
#   <nireHosts.durandal/hardware>   all submodules under hardware/
#   <nireHosts.durandal/fixes> all packages under fixes/

{ lib, nireHosts, ... }:
let
    hostNamespace = nireHosts.durandal;

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
    nireHosts.${category} = {
      # <nireHosts.category> pulls in everything in this category
      includes = map (n: hostNamespace._.${n}) allPackages;

      # <nireHosts.category/subcategory> pulls in just that subcategory
      _ = lib.mapAttrs (sub: _: {
        includes = map (n: hostNamespace._.${n}) (packagesOf sub);
      }) subcategories;
    };
}
