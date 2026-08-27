# Template: copy this file, unchanged, into any new category directory.
#
# Historical note this template used to carry inline, kept here rather than
# dropped since the code it described has moved, not disappeared: this
# mechanism was named `dirBasedProvides.nix` before a rename, and the actual
# collection logic (walking directories, resolving names to real module
# references per class) used to live in every one of these files by hand.
# As of 2026-08-27 it lives once, in `modules/_lib/category-collector.nix` --
# see that file and `flake/doc/dirsAsCategory.md`'s History section for the
# refactor that moved it there. This file, like every real category's copy,
# is now just the two-line shim below.
{ config, lib, ... }:
let
  categoryDir = dirOf __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot categoryDir + "/_lib/category-collector.nix") {
  inherit config lib categoryDir;
}
