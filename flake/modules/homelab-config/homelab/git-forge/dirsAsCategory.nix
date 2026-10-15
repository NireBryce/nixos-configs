# Makes this folder a category: one module per class (nixos, homeManager,
# darwin), named after the folder, importing every module filed under it.
# Copy this file unchanged into a folder to make it a category. The logic
# lives once, in modules/_lib/category-collector.nix, whose header explains
# why this passes in its own path and why it walks up to find `modules/`
# instead of using `inputs.self`.
#
# A module collected here must take its name from its filename -- the
# `moduleName = ... __curPos.file` line every module starts with. The
# collector looks modules up by filename, so a hardcoded name that differs
# is silently left out. `just modules` reports one.
{ config, lib, ... }:
let
  shimFile = __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot (dirOf shimFile) + "/_lib/category-collector.nix") {
  inherit config lib shimFile;
}
