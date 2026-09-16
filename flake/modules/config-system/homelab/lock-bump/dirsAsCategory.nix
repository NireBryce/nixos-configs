# Automatically builds category modules for this category from the
# directory structure. The category name is derived from the folder name
# so this file can be copied to any category directory without changes.
# The logic lives in modules/_lib/category-collector.nix -- see that file's
# header for why categoryDir has to stay computed here rather than moving
# into the shared function too, and why the path below walks up to find
# `modules/` instead of using `inputs.self`.
{ config, lib, ... }:
let
  categoryDir = dirOf __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot categoryDir + "/_lib/category-collector.nix") {
  inherit config lib categoryDir;
}
