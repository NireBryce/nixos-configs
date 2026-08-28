# The actual dirsAsCategory logic, factored out of the ~38 identical
# copies (see git history before this file existed -- each
# `dirsAsCategory.nix` was a byte-for-byte duplicate, save a couple
# drifted by a comment word). Not a flake-parts module -- a plain
# function, `import`ed by path from each real `dirsAsCategory.nix`,
# which stays a two-line shim. Safe under modules/ because import-tree
# ignores any path containing "/_" -- same rule
# `nirePackages/_lib/mkPkgModule.nix`,
# `nirePackages/_templates/dirsAsCategory.nix` and
# `nire/impermanence/_disko/impermanence-luks-btrfs.nix` rely on.
#
# categoryDir must stay a parameter: `__curPos.file` resolves at PARSE
# time to wherever the token is written, not call-stack introspection --
# `dirOf __curPos.file` in here would give every caller *this file's*
# directory, collapsing every category to one named `_lib`. See
# CLAUDE.md, "a module's name is its filename", and
# `nirePackages/_lib/mkPkgModule.nix`'s header, which keeps `moduleName`
# out of itself for the identical reason.
#
# Callers reach this file by walking up from their own directory to
# `modules/`, not via `inputs.self + "/flake/modules/_lib/..."` -- the
# obvious depth-independent path, and it does NOT work: a NixOS module's
# `inputs.self` is evaluated downstream once `self` exists, but every
# `dirsAsCategory.nix` shim is itself one of the flake-parts modules
# composing `flake.modules`, which composes `self` -- `inputs.self`
# there forces the very fixed point the shim contributes to, failing as
# `infinite recursion encountered` at
# `outputs = flake.outputs (inputs // { self = result; })` in
# call-flake.nix.
#
# A nested category (one whose directory owns its own dirsAsCategory.nix
# -- `nire/hardware/amd`, `nire/homelab/virtualization`,
# `nirePackages/development/langs`, ...) is referenced by name
# (`walkSubdir`) instead of having its files re-derived by every
# ancestor. `forClass` resolves a nested category's name exactly like a
# plain module's (same `flake.modules.<class>` namespace), and "always
# define all three classes, even empty" (below) guarantees the reference
# resolves.
#
# This went through two wrong versions before landing here -- both
# caught by evaluating, not by reasoning about the diff:
#
# 1. A first version put the boundary check only inside `collectModules`,
#    which `modulesOf` invokes already *inside* categoryDir's immediate
#    subdirectories -- the check never examined an immediate subdirectory
#    as a delegation candidate, only third-level nesting that doesn't
#    exist in this repo. Dead code: the verifying `drvPath` fingerprint
#    came back byte-identical only because nothing had changed.
# 2. Making the check fire at the depth that exists (applying it in
#    `allModules` too, as below) without `bareModulesOf` silently dropped
#    `libvirt-vm-llm-sandbox` from `nire-cube`'s `systemd.services`:
#    `virtualization-cube.nix` sits bare in `nire/homelab/virtualization/`'s
#    own root -- deliberately excluded from the `virtualization` category's
#    *own* aggregate (a category collects from subdirectories only), but
#    reaching `nire-cube` only because `homelab` walks into
#    `virtualization/` as *its* subdirectory, where a bare file one level
#    in was never excluded (see `wiki/categories/virtualization.md`'s
#    "This exclusion is category-scoped, not tree-scoped"). Delegating
#    straight to `virtualization`'s aggregate collapsed that independence
#    and lost exactly that file. `bareModulesOf` is the fix: at every
#    nested-category boundary, delegate to the child's own aggregate for
#    what IT collects, but also separately collect bare `.nix` files in
#    the child's own root -- the files its own collector deliberately
#    leaves out, that a plain recursive walk would still sweep in.
#    Verified against all six configurations then present (`nire-durandal`,
#    `nire-cube`, `nire-tenacity`, `nire-lego`, `nire-llm-sandbox`,
#    `nire-lysithea`): `environment.systemPackages`, `systemd.services`
#    and `users.users` identical to the pre-refactor baseline,
#    `libvirt-vm-llm-sandbox` included; `drvPath` shifts on most hosts --
#    expected per flake/doc/dirsAsCategory.md's "Expect drvPath to change
#    from import reordering alone", since a nested category is now
#    referenced once instead of its modules listed twice.
{ config, lib, categoryDir }:
let
    categoryName = baseNameOf categoryDir;
    stripNix = name: lib.removeSuffix ".nix" name;

    # A directory's own bare `.nix` files (not its subdirectories) --
    # what a nested category's OWN collector excludes from its aggregate
    # but an ancestor's plain recursive walk used to sweep in. Re-added
    # at each delegation boundary so delegating doesn't lose them.
    bareModulesOf = dir:
        lib.concatMap
            ({ name, value }:
                if value == "directory"
                then [ ]
                else lib.optional (lib.hasSuffix ".nix" name && name != "dirsAsCategory.nix") (stripNix name))
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

    # Handles one directory entry (`name`, at path `subdir`) uniformly,
    # immediate child of categoryDir or found deeper. If it owns its own
    # dirsAsCategory.nix it's a nested category: delegate to its name,
    # plus any bare files in its own root. Otherwise keep walking.
    walkSubdir = subdir: name:
        if builtins.pathExists (subdir + "/dirsAsCategory.nix")
        then [ name ] ++ bareModulesOf subdir
        else collectModules subdir;

    collectModules = dir:
        lib.concatMap
            ({ name, value }:
                if value == "directory"
                then walkSubdir (dir + "/${name}") name
                else lib.optional (lib.hasSuffix ".nix" name && name != "dirsAsCategory.nix") (stripNix name))
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

    # "A category collects from its *sub*directories only. A .nix file
    # sitting directly in a category directory is collected by nothing"
    # -- categoryDir's own bare files never pass through walkSubdir/
    # collectModules; only its immediate subdirectories do, through the
    # same walkSubdir rule as at every deeper level.
    allModules =
        lib.concatMap
            ({ name, value }: if value == "directory" then walkSubdir (categoryDir + "/${name}") name else [ ])
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir categoryDir));

    # Names have to be resolved to real module references: a bare string
    # in `imports` is treated as a path (`error: string 'bluetooth'
    # doesn't represent an absolute path`). The filter is equally
    # load-bearing -- a directory cannot know which classes a module
    # declares, so asking every class for every name is a
    # missing-attribute error the moment one declares only another.
    #
    # Do NOT make the aggregate attribute conditional on the list being
    # non-empty: that would require reading flake.modules.<class>.
    # Empty aggregates are harmless. See flake/doc/dirsAsCategory.md.
    forClass = class:
        map (n: config.flake.modules.${class}.${n})
            (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);

in
{
    flake.modules.nixos.${categoryName}.imports        = forClass "nixos";
    flake.modules.homeManager.${categoryName}.imports  = forClass "homeManager";
    flake.modules.darwin.${categoryName}.imports       = forClass "darwin";
}
