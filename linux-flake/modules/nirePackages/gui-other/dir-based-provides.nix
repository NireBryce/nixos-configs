{ inputs, lib, nirePackages, ... }:
let
  # discover category dirs under ./
  categories = lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./_);

  # for each category, get the package names from the filenames/dirnames inside it
  fileToName = name: type:
    if type == "directory" then name
    else lib.removeSuffix ".nix" name;

  categoryNames = lib.mapAttrs
    (cat: _: lib.mapAttrsToList fileToName (builtins.readDir (./_/${cat})))
    categories;
in {
  nirePackages.packages.provides = lib.mapAttrs (cat: names: {
    includes = map (n: nirePackages.packages.provides.${n}) names;
  }) categoryNames;

  nirePackages.packages.includes = lib.attrValues
    (removeAttrs nirePackages.packages.provides (builtins.attrNames categories));
}
