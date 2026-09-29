# This file, modules/_lib/category-collector.nix, is the logic that every
# `dirsAsCategory.nix` in the tree runs.
#
# ── the problem this solves ─────────────────────────────────────────────────
#
# A `dirsAsCategory.nix` turns its folder into one importable module that
# imports every module under that folder -- a *category*, named after the
# folder. Hosts import categories ("give me `shell-apps`"), almost never
# individual modules (the exceptions, `kde-desktop` and `jovian`, come from
# `desktop-env`, a category deliberately never imported whole).
#
# Why bother? Picture a few hundred small modules -- one for ripgrep, one
# for the bootloader, one per self-hosted service -- and a handful of
# machines that each want a different mix. The obvious design is a list per
# host naming every module it wants. Those lists are where things break:
#
# - Rename a module, and every list that named it is now wrong.
# - Move a module to a different group, and every list has to be edited to
#   match -- or the host keeps the old grouping without anyone noticing.
# - Add a module, and every host that should get it needs a new line.
#
# With categories, where a file sits *is* its membership. Rename it, and
# no host file changes, because no host names it. Move it to a
# different folder, and it is recategorized in the same step -- the move
# is the whole edit. Add one by dropping it in a folder. No host file is
# touched in any of these.
#
# Each `dirsAsCategory.nix` is a small shim that says "here's where I am"
# and hands its own path to this file, which does the actual work: one
# copy of the logic, ~40 folders using it. (This file isn't itself a
# module, just a function. It can sit under modules/ because the tool that
# auto-loads everything there, import-tree, skips any path containing
# `/_` -- which is why it's in `_lib/`.)
#
# ── one file, three kinds of config ─────────────────────────────────────────
#
# A NixOS machine's config, a user's Home Manager config, and a Mac's
# nix-darwin config are normally three separate module systems, each with
# its own files. flake-parts (its `flake.modules` option, enabled in
# flake.nix) lets them share one: every module file here is a flake-parts
# module, and it publishes each piece under a *class* --
#
#   flake.modules.nixos.<name>         system config
#   flake.modules.homeManager.<name>   user config
#   flake.modules.darwin.<name>        macOS config
#
# -- so one source file can carry every side of one feature. zsh.nix, for
# example, declares both `flake.modules.nixos.zsh` (enable zsh system-wide,
# register it as a login shell) and `flake.modules.homeManager.zsh` (the
# user's plugins and dotfiles). Change zsh, and there's one file to edit.
#
# A category follows the same split: each one comes out as three modules,
# one per class, each importing only the matching halves (empty, if nothing
# in the folder has that class):
#
#   flake.modules.nixos.shell-apps
#   flake.modules.homeManager.shell-apps
#   flake.modules.darwin.shell-apps
#
# ── the one rule: what a category imports ───────────────────────────────────
#
# A category imports every `.nix` module under its folder, however deep.
# That's it. Here's packages-config/shell-apps/:
#
#   shell-apps/                      category `shell-apps`
#   ├── dirsAsCategory.nix           the shim -- skipped, it's not a module
#   ├── find/
#   │   └── fzf.nix                  in shell-apps
#   └── text-tools/                  also a category: `text-tools`
#       ├── dirsAsCategory.nix
#       ├── ripgrep.nix              in shell-apps and text-tools
#       └── pagers/
#           └── bat.nix              in shell-apps and text-tools
#
# Folders are just for tidiness -- `find/` and `pagers/` mean nothing to the
# code. The one exception is a name starting with `_` (`_lib/`,
# `_templates/`): import-tree never loads those as modules, so the collector
# doesn't look in them either -- that's where helper functions live. The
# only way to keep a module *out* of a category is to put it outside that
# folder. Something only one machine needs goes under
# host-config/<that host>/, which only that host imports.
#
# Three smaller things follow from how this works:
#
# - A module's name is its filename. ripgrep.nix declares a module called
#   `ripgrep`, and that's the name we look up. Every module file gets this
#   for free by computing its name from its own filename (the
#   `moduleName = ... __curPos.file` line at the top of each one). Hardcode
#   a different name instead and the lookup silently misses it. Keep the
#   line; `just modules` reports a module whose declared name isn't its
#   filename.
# - A module only shows up in the kinds of config it actually provides. The
#   micro editor only has user config, so it appears in `editors` for
#   homeManager and simply isn't there for nixos. A folder can't know what
#   its files provide, so we check each one (that's forClass, below).
# - Don't name a module after its own category. Folder names are free --
#   editors/micro/micro.nix is fine -- but a file `shell-apps.nix` inside
#   shell-apps/ would declare the same name as the category, and the two
#   would silently *merge*. This has happened three times (lessons-learned
#   §34, §35); `just modules` checks for it now.
#
# ── categories inside categories ────────────────────────────────────────────
#
# Notice `text-tools` above: a category inside a category. That's useful --
# a host can import all of `shell-apps`, or just `text-tools` if that's all
# it needs. The same goes for general-config/hardware/amd/ inside
# `hardware`, and the service categories inside `homelab`.
#
# When shell-apps is collecting and reaches text-tools/, it could walk in and
# list everything by hand. But text-tools already did that work -- it's a
# category, it has its own finished list. So shell-apps just adds the *name*
# "text-tools", and when names get turned into modules, that name turns into
# text-tools' whole collection:
#
#   shell-apps looks at each folder:
#
#     find/          plain folder    -> walk in          -> fzf, fd
#     text-tools/    a category      -> add its name     -> ripgrep, bat, ...
#
# Same result as walking in, nothing listed twice, and it works however deep
# the nesting goes.
#
# ── two things you can't move (and why) ─────────────────────────────────────
#
# These look like obvious cleanups. Both break things.
#
# 1. Q: The shim works out its own path and passes it in as `shimFile`.
#       Why not work it out in here instead?
#
#    A: The trick it uses, `__curPos.file`, answers "which file is this
#       line of code written in?" -- and it's answered when the file is
#       *read*, not when it runs. Written in here, it would give every
#       category the same answer: this file, in `_lib/`. You'd get one
#       category, called `_lib`.
#
# 2. Q: The shim finds this file by walking up the path until it hits
#       `modules/`. Why not the tidier `inputs.self`, "the root of this
#       flake"?
#
#    A: The shims are part of *building* that root. Asking for it from
#       inside one is asking for something that's only finished once
#       you're done -- Nix reports `infinite recursion`.
#
# ── why the shim's own name is never written down here ──────────────────────
#
# The collector has to recognise shims twice: to skip them while collecting
# (they aren't modules), and to spot a subfolder that is itself a category.
# Both use the filename the calling shim reports about itself (`shimName`),
# not a hardcoded "dirsAsCategory.nix". Rename every shim consistently and
# nothing here needs to change.
#
# That's not hypothetical: when the shim was renamed from
# `dirsAsProvides.nix`, a hardcoded name here was missed, and every category
# quietly collected a module called `dirsAsCategory`. Nothing complained --
# forClass drops names no module declares, which hides a mistake like that
# rather than catching it. `just modules` also reports shims whose names or
# contents have drifted apart.
#
# If you change the logic here: read flake/doc/dirsAsCategory.md first, and
# check your work by comparing each host's actual config before and after
# (scripts/host-fingerprint.nix), not just whether the hashes match. The
# history section at the bottom is why.
{ config, lib, shimFile }:
let
    categoryDir = dirOf shimFile;
    categoryName = baseNameOf categoryDir;
    shimName = baseNameOf shimFile;
    stripNix = name: lib.removeSuffix ".nix" name;

    # For one folder, at any depth: if it's a category, contribute its name
    # (see "categories inside categories"); otherwise walk into it.
    walkSubdir = subdir: name:
        if builtins.pathExists (subdir + "/${shimName}")
        then [ name ]
        else collectModules subdir;

    # List every module name in a folder: each `.nix` file becomes its
    # filename minus `.nix`, and each subfolder adds whatever walkSubdir
    # says. Called on the category's own folder to start things off.
    # Anything starting with `_` is skipped, same as import-tree does.
    collectModules = dir:
        lib.concatMap
            ({ name, value }:
                if lib.hasPrefix "_" name then [ ]
                else if value == "directory"
                then walkSubdir (dir + "/${name}") name
                else lib.optional (lib.hasSuffix ".nix" name && name != shimName) (stripNix name))
            (lib.mapAttrsToList lib.nameValuePair (builtins.readDir dir));

    # Turn the list of names into actual modules, for one kind of config.
    #
    # Why not just hand over the names? Because `imports` treats a string
    # as a file path -- you get `string 'bluetooth' doesn't represent an
    # absolute path`. So we look each name up.
    #
    # The filter (`?` means "does this exist?") skips names this kind of
    # config doesn't have. Without it, asking nixos for `micro`, which only
    # has user config, is an error.
    #
    # One more subtlety: all three kinds get a module below even when the
    # list is empty. It's tempting to skip the empty ones, but deciding
    # "is it empty?" means reading `flake.modules.<kind>`, which is the very
    # thing we're in the middle of defining -- infinite recursion again. An
    # empty module does nothing, so leaving it in is free.
    forClass = class:
        map (n: config.flake.modules.${class}.${n})
            (lib.filter (n: config.flake.modules.${class} ? ${n}) (collectModules categoryDir));

in
{
    flake.modules = {
        nixos.${categoryName}.imports        = forClass "nixos";
        homeManager.${categoryName}.imports  = forClass "homeManager";
        darwin.${categoryName}.imports       = forClass "darwin";
    };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# Until 2026-09-28 a category skipped the `.nix` files directly in its own
# directory, and a helper, bareModulesOf, added a nested category's skipped
# files back into its parent. Both are gone; flake/doc/dirsAsCategory.md's
# History section has why and what moved. The lesson that outlived them:
# delegating to nested categories by name first shipped without
# bareModulesOf and silently dropped a VM from nire-cube (2026-08-27) --
# drvPath fingerprints didn't catch it, evaluating `systemd.services` did.
