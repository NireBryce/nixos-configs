# The actual dirsAsCategory logic, factored out of the ~38 identical copies
# that used to carry it in full (see git history before this file existed --
# each `dirsAsCategory.nix` under modules/ was a byte-for-byte duplicate, save
# for a couple of files that had drifted by a comment word). Not a flake-parts
# module itself -- a plain function, `import`ed by path from each real
# `dirsAsCategory.nix`, which stays a two-line shim. Safe to sit under
# modules/ specifically because import-tree ignores any path containing "/_"
# by default -- same rule `nirePackages/_lib/mkPkgModule.nix`,
# `nirePackages/_templates/dirsAsCategory.nix` and
# `nire/impermanence/_disko/impermanence-luks-btrfs.nix` already rely on.
#
# categoryDir has to stay a parameter, not something derived in here.
# `__curPos.file` resolves to wherever that token is written in source, at
# PARSE time -- it is not call-stack introspection. If `dirOf __curPos.file`
# moved into this file, every caller would get *this file's own* directory
# instead of theirs, and every category would collapse to one named `_lib`.
# See CLAUDE.md, "a module's name is its filename", and
# `nirePackages/_lib/mkPkgModule.nix`'s own header, which keeps `moduleName`
# out of itself for the identical reason.
#
# Each caller reaches this file by walking up from its own directory to find
# `modules/`, not via `inputs.self + "/flake/modules/_lib/..."`. The latter
# looks like the obvious way to get a depth-independent path and does NOT
# work: unlike a NixOS module's use of `inputs.self` (e.g.
# installer-configuration.nix, evaluated downstream once `self` already
# exists), every `dirsAsCategory.nix` shim is itself one of the flake-parts
# modules that compose `flake.modules`, which composes `self`. Referencing
# `inputs.self` from there forces the very fixed point the shim contributes
# to, and fails as `infinite recursion encountered` at
# `outputs = flake.outputs (inputs // { self = result; })` in
# call-flake.nix -- confirmed by trying it before writing the walk-up
# version below.
#
# A nested category (one whose directory owns its own dirsAsCategory.nix --
# `nire/hardware/amd`, `nire/homelab/virtualization`, `nirePackages/development/langs`,
# ...) is referenced by name (`walkSubdir`) instead of having its files
# re-derived from scratch by every ancestor. `forClass` resolves a nested
# category's name exactly like a plain module's, because both live in the
# same `flake.modules.<class>` namespace, and "always define all three
# classes, even empty" (below) guarantees the reference always resolves.
#
# This went through two wrong versions before landing here -- both caught by
# evaluating, not by reasoning about the diff, and worth knowing before
# touching this file again:
#
# 1. A first version put the boundary check only inside `collectModules`,
#    which is invoked by `modulesOf` already *inside* each of categoryDir's
#    immediate subdirectories -- so the check never got to examine an
#    immediate subdirectory itself as a delegation candidate, only a third
#    level of nesting that doesn't exist anywhere in this repo. It shipped as
#    dead code: the `drvPath` fingerprint used to verify the refactor came
#    back byte-identical, but only because nothing had actually changed.
# 2. Making the check fire at the depth that exists (applying it in
#    `allModules` too, as below) without `bareModulesOf` silently dropped
#    `libvirt-vm-llm-sandbox` from `nire-cube`'s `systemd.services`.
#    `virtualization-cube.nix` sits bare in `nire/homelab/virtualization/`'s
#    own root -- deliberately excluded from the `virtualization` category's
#    *own* aggregate (a category collects from subdirectories only), but it
#    reaches `nire-cube` at all only because `homelab` used to walk into
#    `virtualization/` independently, as *its* subdirectory, where a bare
#    file one level in was never excluded (see
#    `wiki/categories/virtualization.md`'s "This exclusion is category-scoped,
#    not tree-scoped" section). Delegating straight to `virtualization`'s
#    aggregate collapsed that independence and lost exactly that file.
#    `bareModulesOf` is what fixes this: at every nested-category boundary,
#    delegate to the child's own aggregate for what IT collects, but also
#    separately still collect any bare `.nix` files sitting directly in that
#    child's own root -- the files its own collector deliberately leaves out
#    of its aggregate, that a plain recursive walk would otherwise still
#    sweep in. Verified against all six configurations (`nire-durandal`,
#    `nire-cube`, `nire-tenacity`, `nire-lego`, `nire-llm-sandbox`,
#    `nire-lysithea`): `environment.systemPackages`, `systemd.services`, and
#    `users.users` all came back exactly identical to the pre-refactor
#    baseline, `libvirt-vm-llm-sandbox` included. `drvPath` itself does shift
#    on most hosts -- expected, per this doc's own "Expect drvPath to change
#    from import reordering alone" note, since a nested category is now
#    referenced once instead of having its modules listed a second time.
{ config, lib, categoryDir }:
let
    categoryName = baseNameOf categoryDir;
    stripNix = name: lib.removeSuffix ".nix" name;

    # A directory's own bare `.nix` files (not its subdirectories) --
    # what a nested category's OWN collector deliberately excludes from its
    # aggregate, but what an ancestor's plain recursive walk always used to
    # sweep in regardless. Re-added at each delegation boundary so
    # delegating doesn't lose them.
    bareModulesOf = dir:
        lib.concatMap
            ({ name, value }:
                if value == "directory"
                then [ ]
                else lib.optional (lib.hasSuffix ".nix" name && name != "dirsAsCategory.nix") (stripNix name))
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

    # Handles one directory entry (`name`, at path `subdir`) uniformly,
    # whether it's an immediate child of categoryDir or found deeper during
    # recursion. If it owns its own dirsAsCategory.nix, it's a nested
    # category: delegate to its name, plus any bare files in its own root.
    # Otherwise, keep walking into it.
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
    # sitting directly in a category directory is collected by nothing" --
    # categoryDir's own bare files are never passed through walkSubdir/
    # collectModules; only its immediate subdirectories are, through the same
    # walkSubdir rule that applies at every deeper level too.
    allModules =
        lib.concatMap
            ({ name, value }: if value == "directory" then walkSubdir (categoryDir + "/${name}") name else [ ])
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir categoryDir));

    # Names have to be resolved to real module references: a bare string in
    # `imports` is treated as a path (`error: string 'bluetooth' doesn't represent
    # an absolute path`). The filter is equally load-bearing -- a directory cannot
    # know which classes a module declares, so asking every class for every name
    # is a missing-attribute error the moment one of them only declares another.
    #
    # Do NOT make the aggregate attribute itself conditional on the list being
    # non-empty: computing the attribute names of flake.modules.<class> would then
    # require reading flake.modules.<class>. Empty aggregates are harmless.
    # See flake/doc/dirsAsCategory.md.
    forClass = class:
        map (n: config.flake.modules.${class}.${n})
            (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);

in
{
    flake.modules.nixos.${categoryName}.imports        = forClass "nixos";
    flake.modules.homeManager.${categoryName}.imports  = forClass "homeManager";
    flake.modules.darwin.${categoryName}.imports       = forClass "darwin";
}
