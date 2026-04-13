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
{ lib, den, ... }:
let


  aspectDir = dirOf __curPos.file;
  aspectNamespace = baseNameOf (dirOf aspectDir);
  aspectName = baseNameOf aspectDir;

  onlyDirs = lib.filterAttrs (_: t: t == "directory");
  stripNix = name: lib.removeSuffix ".nix" name;

  # Subcategories are directories at this level
  subcategories = onlyDirs (builtins.readDir aspectDir);

  collectModules =
    dir:
    lib.concatMap (
      { name, value }:
      if value == "directory" then collectModules (dir + "/${name}") else [ (stripNix name) ]
    ) (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

  # Package names within a subcategory
  modulesOf = sub: collectModules (aspectDir + "/${sub}");

  # All module names across all subcategories
  # allModules = lib.concatMap modulesOf (lib.attrNames subcategories);
  allModules = builtins.trace "allModules: ${builtins.toJSON (lib.concatMap modulesOf (lib.attrNames subcategories))}" (
    lib.concatMap modulesOf (lib.attrNames subcategories)
  );

in
{
  den.ful.${aspectNamespace}.${aspectName} = {
    # <nireHosts.category> pulls in everything in this category
    includes = map (n: den.ful.nire.moduleStore._.${n}) allModules;

    # <nireHosts.category/subcategory> pulls in just that subcategory
    _ = lib.mapAttrs (sub: _: {
      includes = map (n: den.ful.nire.moduleStore._.${n}) (modulesOf sub);
    }) subcategories;
    
  };
}
# # brings individual submodule names into the category, add to _ =
#
# // lib.genAttrs allModules (n: {
#     includes = [ den.ful.nire.moduleStore._.${n} ];
# });
