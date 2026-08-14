# DRAFT -- not wired into any caller yet. See flake/scripts/mkPkgModule.md for
# what this is and why nothing in the tree uses it.
#
# Generator for the single-package home.packages wrapper shape ~70 files in
# this tree already share by hand (which.nix, jq.nix, vlc.nix, most of
# linux-utils/, ...). Not a flake-parts module itself -- a plain function,
# `import`ed by path from whichever module wants it. Safe to sit under
# modules/ specifically because import-tree ignores any path containing "/_"
# by default (see its README; _templates/dirsAsCategory.nix already relies
# on the same rule to be a harmless copy-source rather than a real category).
#
# moduleName has to stay a parameter, not something derived in here.
# `__curPos.file` resolves to wherever that token is written in source, at
# PARSE time -- it is not call-stack introspection. If the `baseNameOf
# __curPos.file` step moved into this file, it would report this file's own
# name for every caller instead of theirs. See CLAUDE.md, "a module's name
# is its filename". That's the one thing this deliberately does NOT try to
# factor out.
#
# There is deliberately no `linuxOnly` parameter. It had one until 2026-08-12,
# wrapping the body in lib.mkIf (!pkgs.stdenv.isDarwin), and it is now
# redundant: nire/system/home-manager/drop-unsupported-packages.nix filters
# home.packages by meta.platforms on darwin already. A package that cannot
# build there needs no annotation here, and one that CAN build there but is
# unwanted anyway -- the linux-utils/ tools -- is a preference, which belongs
# in the module as an explicit mkIf where a reader will see it, not as a flag
# passed to a generator.
{ moduleName
, packages          # list of pkgs attribute paths, e.g. [ "which" ] or [ "kdePackages.kate" ]
}:
{
    flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
        let
            resolve = name:
                lib.attrByPath (lib.splitString "." name)
                    (throw "mkPkgModule (${moduleName}): pkgs has no attribute '${name}'")
                    pkgs;
        in
            { home.packages = map resolve packages; };
}

# ── worked example, not real -- see README.md ────────────────────────────
#
# which.nix today:
#
#     { lib, ... }:
#         let
#             moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
#         in {
#             flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
#                 home.packages = with pkgs; [ which ];
#             };
#     }
#
# which.nix using this generator:
#
#     { lib, ... }:
#     let
#         moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
#     in
#         import ../../_lib/mkPkgModule.nix { inherit moduleName; packages = [ "which" ]; }
#
# vlc.nix the same way. Nothing extra is needed for it despite not building on
# aarch64-darwin -- drop-unsupported-packages.nix handles that from
# meta.platforms:
#
#     import ../../../_lib/mkPkgModule.nix {
#         inherit moduleName;
#         packages = [ "vlc" ];
#     }
#
# A module that IS buildable on darwin but unwanted there anyway -- ipcalc.nix
# and the rest of linux-utils/ -- cannot use this generator as written, and
# should keep its explicit mkIf. That is the one case the generator gives up.
