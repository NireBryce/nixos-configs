# DRAFT -- not wired into any caller yet. See ../../../mkPkgModule.md (repo
# root, alongside dirsAsCategory.md) for what this is and why nothing in the
# tree uses it.
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
{ moduleName
, packages          # list of pkgs attribute paths, e.g. [ "which" ] or [ "kdePackages.kate" ]
, linuxOnly ? false  # wraps the module in lib.mkIf (!pkgs.stdenv.isDarwin)
}:
{
    flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
        let
            resolve = name:
                lib.attrByPath (lib.splitString "." name)
                    (throw "mkPkgModule (${moduleName}): pkgs has no attribute '${name}'")
                    pkgs;
            body = { home.packages = map resolve packages; };
        in
            if linuxOnly then lib.mkIf (!pkgs.stdenv.isDarwin) body else body;
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
# vlc.nix (linuxOnly) the same way:
#
#     import ../../../_lib/mkPkgModule.nix {
#         inherit moduleName;
#         packages = [ "vlc" ];
#         linuxOnly = true;
#     }
