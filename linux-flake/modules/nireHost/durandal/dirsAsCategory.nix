# Automatically builds category modules for this category from the
# directory structure. The category name is derived from the folder name
# so this file can be copied to any category directory without changes.
# One day I will un-hack this and turn it into a library function or something
{ lib, ... }:
let
  categoryDir = dirOf __curPos.file;
  categoryName = baseNameOf categoryDir;

  onlyDirs = lib.filterAttrs (_: t: t == "directory");
  stripNix = name: lib.removeSuffix ".nix" name;

  # Subcategories are directories at this level, ie under ./
  subcategories = onlyDirs (builtins.readDir categoryDir);

  collectModules = dir:
    lib.concatMap
      ({ name, value }:
        if value == "directory"
        then collectModules (dir + "/${name}")
        else lib.optional (lib.hasSuffix ".nix" name && name != "dirsAsCategory.nix") (stripNix name))
      (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

  # Package names within a subcategory
  modulesOf = sub: collectModules (categoryDir + "/${sub}");

  # All module names across all subcategories
  allModules = lib.concatMap modulesOf (lib.attrNames subcategories);

in
{
  # eventually these should turn into something that's determined by option
  flake.modules.nixos.${categoryName} = {
        imports = allModules;
  };
  flake.modules.homeManager.${categoryName} = {
        imports = allModules;
  };
  flake.modules.darwin.${categoryName} = {
        imports = allModules;
  };
}
