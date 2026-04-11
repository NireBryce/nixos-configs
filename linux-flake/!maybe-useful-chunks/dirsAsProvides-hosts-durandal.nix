# Claude co-written magic, my nix is not deep enough here even though I can follow it.
# 
# modules/<namespace>/<subcategory>/dirBasedProvides.nix
#
# Automatically builds subcategory aspects for this category from the
# directory structure. The category name is derived from the folder name
# so this file can be copied to any category directory without changes.
#
# Example structure:
#   nireHosts/
#     durandal/
#       dirsAsProvides.nix  <- this file
#       hardware/               -> nireHost.durandal._.hardware
#         hardware-configuration.nix    -> nireHost.durandal._.hardware-configuration
#       fixes/                  -> nireHost.durandal._.fixes
#         b550-suspend-fix.nix          -> nireHost.durandal._.b550-suspend-fix
#       
# Produces:
#   <nireHosts.durandal>            all submodules in this category
#   <nireHosts.durandal/hardware>   all submodules under hardware/
#   <nireHosts.durandal/fixes>      all packages under fixes/
#   <nireHosts.durandal/hostName>   only nireHost/durandal/configuration/hostname.nix 

{ lib, nireHosts, ... }:
let
    baseNamespace = nireHosts; # don't forget to add it in the top module args too
    
    root        = dirOf __curPos.file;
    category    = baseNameOf root;
    flatStore   = baseNamespace.${category};

    onlyDirs    = lib.filterAttrs (_: t: t == "directory");
    onlyFiles   = lib.filterAttrs (_: t: t == "regular");
    stripNix    = name: lib.removeSuffix ".nix" name;

    # Subcategories are directories at this level
    subcategories = onlyDirs (builtins.readDir root);

    # Package names within a subcategory
    modulesOf = sub:
      lib.mapAttrsToList (name: _: stripNix name)
        (onlyFiles (builtins.readDir (root + "/${sub}")));

    # All package names across all subcategories
    allModules = lib.concatMap modulesOf (lib.attrNames subcategories);

in {
    nireHosts.${category} = {
      # <nireHosts.category> pulls in everything in this category
      includes = map (n: flatStore._.${n}) allModules;

      # <nireHosts.category/subcategory> pulls in just that subcategory
      _ = lib.mapAttrs (sub: _: {
        includes = map (n: flatStore._.${n}) (modulesOf sub);
      }) subcategories;
    };
}
