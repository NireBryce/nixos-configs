# Recipes work from anywhere in the repo.
#
# `just` runs recipes from the directory holding this justfile, which is the
# repo root -- and the root has no flake.nix. Every recipe therefore has to
# point at linux-flake explicitly; `.#` would resolve against the root and fail.
#
# Note that `just --list` shows only the LAST comment line above a recipe, so
# each one gets a single-line summary and any detail goes in the body.

flake := justfile_directory() / "linux-flake"
user  := "elly"

# Default to the machine you are standing on, when that is one of the hosts.
#
# This used to be a flat "nire-durandal", which meant a plain `just build` on
# tenacity spent an hour building the wrong machine and said nothing about it.
#
# Derived from the host configs on disk rather than a hardcoded list of
# hostnames: `nire-tenacity` -> nireHost/tenacity-configuration.nix. A third
# host is picked up by existing, with no edit here -- which matters, because
# the failure mode of forgetting is the silent wrong-machine build this exists
# to prevent. Anywhere with no matching config -- the darwin laptop, a
# container -- it falls back to durandal, as before.
#
# Overriding is unchanged and the assignment still goes BEFORE the recipe name:
#     just host=nire-durandal build
# `just build host=nire-durandal` is not a variant of that; just reads it as a
# second recipe name and errors.
host := `h=$(hostname); [ -e "linux-flake/modules/nireHost/${h#nire-}-configuration.nix" ] && echo "$h" || echo nire-durandal`

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
    @echo "==> building {{host}}   (override: just host=<other> build)"
    nh os build {{flake}} --hostname {{host}}

# Build and make it the boot default, activating nothing now
boot:
    # The safe first step for a config that has never booted: nothing changes
    # until you reboot deliberately, and the running generation stays in the
    # systemd-boot menu as the fallback.
    @echo "==> {{host}} will be the boot default on next reboot"
    nh os boot {{flake}} --hostname {{host}}

# Build and activate, applying Home Manager too
switch:
    # HM is NixOS-integrated here, so there is no separate `nh home switch`.
    @echo "==> ACTIVATING {{host}} now, home-manager included"
    nh os switch {{flake}} --hostname {{host}}

# Package-level diff between what is running and what would be installed
diff-deployed:
    # Answers the question a drvPath cannot: which packages actually move. A
    # nixpkgs bump shows up here as a list of version changes rather than one
    # different hash.
    #
    # Needs the new toplevel to exist, so run it AFTER `just build` and before
    # `just boot`. Linux only, and only meaningful on the host itself.
    #
    # Guarded rather than left to nix: unbuilt, it otherwise fails with "there
    # is no substituter that can build it", which is true and unhelpful.
    @cd {{flake}} && top=$(nix eval --raw \
        '.#nixosConfigurations.{{host}}.config.system.build.toplevel') && \
    if [ -e "$top" ]; then \
        nix store diff-closures /run/current-system "$top"; \
    else \
        echo "{{host}} is not built yet -- run \`just build\` first."; \
        echo "  wanted: $top"; \
        exit 1; \
    fi

# What this machine is really running -- capture BEFORE switching
baseline:
    # Everything it prints stops being recoverable once the new generation boots
    # and the store is collected. lessons.md §24 covers why that matters; run it
    # with sudo to include the btrfs subvolumes.
    @{{justfile_directory()}}/linux-flake/scripts/deployed-baseline.sh

# Which files home-manager will take over, and whether any would collide
hm-collisions:
    # Run before the first switch on a host. Classifies by where each path
    # resolves rather than by whether its leaf is a symlink, which is what makes
    # ~/.just/.justfile and ~/.config/broot look like conflicts when they are not.
    @{{justfile_directory()}}/linux-flake/scripts/hm-collisions.sh {{host}} {{user}}

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
