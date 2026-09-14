# The actual dirsAsCategory logic, factored out of the ~38 byte-for-byte
# identical copies each `dirsAsCategory.nix` used to hold. Not a flake-parts
# module -- a plain function, `import`ed by path from each real
# `dirsAsCategory.nix`, which stays a two-line shim. Safe under modules/
# because import-tree ignores any path containing "/_".
#
# READ flake/doc/dirsAsCategory.md BEFORE CHANGING ANY OF THIS. It is this
# file's companion and carries the full mechanism: why callers walk up to
# `modules/` instead of using `inputs.self` (which forces the very fixed
# point the shim contributes to -- `infinite recursion` out of
# call-flake.nix), how nested categories are referenced by name rather than
# re-derived, why every class is defined even when empty, and the two wrong
# versions this went through -- the second of which silently dropped a
# module from a host because a nested category's bare root files are
# collected by its parent but excluded from its own aggregate. That is what
# `bareModulesOf` exists for; both wrong versions were caught by evaluating,
# not by reading the diff.
#
# `categoryDir` MUST STAY A PARAMETER: `__curPos.file` resolves at PARSE
# time to wherever the token is written, so `dirOf __curPos.file` in here
# would hand every caller THIS file's directory and collapse every category
# into one named `_lib`.
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
    flake.modules = {
        nixos.${categoryName}.imports        = forClass "nixos";
        homeManager.${categoryName}.imports  = forClass "homeManager";
        darwin.${categoryName}.imports       = forClass "darwin";
    };
}
