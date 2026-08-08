# Claude co-written magic, my nix is not deep enough here even though I can follow it.
#
# modules/<namespace>/<subcategory>/dirBasedProvides.nix
#
# Automatically builds category modules for this category from the
# directory structure. The category name is derived from the folder name
# so this file can be copied to any category directory without changes.
{ config, lib, ... }:
let
  categoryDir = dirOf __curPos.file;
  categoryName = baseNameOf categoryDir;

  onlyDirs = lib.filterAttrs (_: t: t == "directory");
  stripNix = name: lib.removeSuffix ".nix" name;

  # Subcategories are directories at this level
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
  # Names have to be resolved to real module references: a bare string in
  # `imports` is treated as a path (`error: string 'bluetooth' doesn't represent
  # an absolute path`). The filter is equally load-bearing -- a directory cannot
  # know which classes a module declares, so asking every class for every name
  # is a missing-attribute error the moment one of them only declares another.
  #
  # Do NOT make the aggregate attribute itself conditional on the list being
  # non-empty: computing the attribute names of flake.modules.<class> would then
  # require reading flake.modules.<class>. Empty aggregates are harmless.
  # See linux-flake/dirsAsCategory.md.
  forClass = class:
    map (n: config.flake.modules.${class}.${n})
        (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);

in
{
  flake.modules.nixos.${categoryName}.imports        = forClass "nixos";
  flake.modules.homeManager.${categoryName}.imports  = forClass "homeManager";
  flake.modules.darwin.${categoryName}.imports       = forClass "darwin";
}
