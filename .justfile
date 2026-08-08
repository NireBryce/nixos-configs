# Recipes work from anywhere in the repo.
#
# `just` runs recipes from the directory holding this justfile, which is the
# repo root -- and the root has no flake.nix. Every recipe therefore has to
# point at linux-flake explicitly; `.#` would resolve against the root and fail.
#
# Note that `just --list` shows only the LAST comment line above a recipe, so
# each one gets a single-line summary and any detail goes in the body.

flake := justfile_directory() / "linux-flake"
host  := "nire-durandal"
user  := "elly"

_default:
    @just --list

# Evaluate every output without building anything -- the real check
check:
    cd {{flake}} && nix flake check --all-systems --no-build

# Static check: module/category name collisions and unreachable modules
modules:
    # Platform independent, so this is the one check that means anything on darwin.
    cd {{flake}} && python3 scripts/modules.py check modules

# Build this host, without activating it
build:
    # Linux only. The dev machine is darwin and the host is x86_64-linux, so this
    # needs a remote builder or binfmt; neither is set up.
    nh os build {{flake}} --hostname {{host}}

# Build and activate, applying Home Manager too
switch:
    # HM is NixOS-integrated here, so there is no separate `nh home switch`.
    nh os switch {{flake}} --hostname {{host}}

# drvPath of the host toplevel, for before/after comparison
fingerprint:
    # A differing hash does not prove breakage: reordering imports permutes
    # list-valued options like environment.systemPackages. Compare sets too.
    @cd {{flake}} && nix eval --raw \
        .#nixosConfigurations.{{host}}.config.system.build.toplevel.drvPath
    @echo

# What changed in the host's config vs a git ref: `just diff HEAD~1`
diff ref:
    # Says *what* differs when the drvPath moves, which a hash cannot. Evaluates
    # both sides in a throwaway worktree; builds nothing, so it works from darwin.
    @{{justfile_directory()}}/linux-flake/scripts/diff-config.sh {{ref}} {{host}}

# drvPath of the home activation package
fingerprint-home:
    @cd {{flake}} && nix eval --raw \
        '.#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.activationPackage.drvPath'
    @echo

# Every generated dotfile's attribute name -- run this before `just dotfile`
dotfiles:
    @cd {{flake}} && nix eval --json \
        '.#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.file' \
        --apply builtins.attrNames | tr ',' '\n' | tr -d '[]"'

# A dotfile as home-manager actually generates it: `just dotfile ./.zshrc`
dotfile name:
    # Shell bugs are visible here and invisible in the .nix source.
    #
    # The attribute name is inconsistent -- it has been ".zshrc", "./.zshrc" and a
    # full /home/elly/... path for different entries -- and a wrong name returns
    # empty rather than erroring, which looks exactly like a real negative. Use
    # `just dotfiles` to get the real names.
    #
    # Some entries have no .text at all and are built from .source; for those,
    # read the owning option instead (e.g. programs.bash.initExtra for .bashrc).
    @cd {{flake}} && nix eval --raw \
        '.#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.file."{{name}}".text'

# Update inputs, then re-check
update:
    cd {{flake}} && nix flake update
    @just check
