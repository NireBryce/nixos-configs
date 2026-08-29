# Recipes work from anywhere in the repo.
#
# This file is an interface, not a home for logic. Anything with a conditional,
# a pipeline or a reason worth explaining belongs in flake/scripts/ --
# where it can be run directly, and where the explanation sits next to the code
# it explains rather than in a recipe body nobody reads. Recipes should stay
# one line of dispatch plus the one-line summary `just --list` shows.
#
# `just` runs recipes from the directory holding this justfile, which is the
# repo root -- and the root has no flake.nix. Every recipe therefore has to
# point at flake explicitly; `.#` would resolve against the root and fail.
#
# Note that `just --list` shows only the LAST comment line above a recipe, so
# each one gets a single-line summary and any detail goes in the script.

flake   := justfile_directory() / "flake"
scripts := justfile_directory() / "flake" / "scripts"
user    := "elly"

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
host := `h=$(hostname); [ -e "flake/modules/nireHost/${h#nire-}-configuration.nix" ] && echo "$h" || echo nire-durandal`

_default:
    @just --list

# Evaluate every output without building anything -- the real check
check:
    cd {{flake}} && nix flake check --all-systems --no-build

# Static check: module/category name collisions and unreachable modules
modules:
    # Platform independent, so this is the one check that means anything on darwin.
    cd {{flake}} && python3 scripts/modules.py check modules

# statix + deadnix + an oversized-file check, ratcheted against a committed baseline
lint:
    # Needs statix/deadnix on PATH -- already there via nirePackages/nix-utils/
    # on a real host; `nix shell nixpkgs#statix nixpkgs#deadnix` first otherwise.
    # A commit can lower the finding count but never raise it -- see
    # flake/scripts/lint.py's own header for why this is a ratchet and not a
    # plain pass/fail, and `just install-hooks` for enforcing it pre-commit.
    cd {{flake}} && python3 scripts/lint.py check

# Static check: wiki claims (import lists) against the actual module tree --
# catches a category page going stale after a refactor. Exits non-zero only
# on a hard finding (MISSING/no-Imported-by-section); a REVIEW-only result
# (heuristic, needs a human look -- see the script's own docstring) prints
# but exits 0. Not part of `preflight` yet -- new and unproven against the
# rest of the wiki's prose style.
wiki-lint:
    python3 wiki/scripts/check_wiki.py check

# Reporting only, never fails -- ranks wiki/ pages by git-log edit churn, to
# spot a page turning into hand-maintained toil (a stale-prone claim nearby
# things keep forcing edits to) before it becomes another categories/
# README.md-Members-column situation (removed 2026-08-29). Pass args through,
# e.g. `just wiki-churn --top 5` or `just wiki-churn --since "3 weeks ago"`.
wiki-churn *args:
    python3 wiki/scripts/wiki_churn.py {{args}}

# Point git at .githooks/: lint ratchet pre-commit, trailer fixup commit-msg
install-hooks:
    git config core.hooksPath .githooks
    @echo "==> git will now run .githooks/pre-commit and .githooks/commit-msg"

# check + modules + lint in one shot -- what the ship skill's step 0 asks for,
# short of the per-host forced toplevel eval that still needs picking a host
preflight:
    @just check
    @just modules
    @just lint

# Build this host, without activating it
build:
    # Runs on the host itself: no remote builder and no binfmt, so a NixOS host
    # cannot be built from the Mac. nire-lysithea IS the Mac, and builds here.
    @echo "==> building {{host}}   (override: just host=<other> build)"
    @{{scripts}}/rebuild.sh build {{flake}} {{host}}

# Build and make it the boot default, activating nothing now
boot:
    # Nothing changes until you reboot deliberately, and the running generation
    # stays in the systemd-boot menu as the fallback. Worth preferring over
    # `switch` for anything touching initrd, the bootloader or impermanence.
    # NixOS only -- nix-darwin has no boot generation; rebuild.sh says so.
    @echo "==> {{host}} will be the boot default on next reboot"
    @{{scripts}}/rebuild.sh boot {{flake}} {{host}}

# Build and activate, applying Home Manager too
switch:
    # HM is integrated on both classes here, so there is no separate
    # `nh home switch` on either.
    @echo "==> ACTIVATING {{host}} now, home-manager included"
    @{{scripts}}/rebuild.sh switch {{flake}} {{host}}

# Package-level diff between what is running and what would be installed
diff-deployed:
    @{{scripts}}/diff-deployed.sh {{host}}

# What this machine is really running -- capture BEFORE switching
baseline:
    # Everything it prints stops being recoverable once the new generation boots
    # and the store is collected. lessons-learned.md §24 covers why that matters; run it
    # with sudo to include the btrfs subvolumes.
    @{{scripts}}/deployed-baseline.sh

# What's on / that no persistence entry covers -- needs sudo, or it says so and exits
root-drift:
    # Everything this lists gets deleted by the impermanence rollback on next
    # boot. Only meaningful on a host that imports `impermanence` -- see
    # CLAUDE.md, Safety.
    @{{scripts}}/root-drift.sh

# Which files home-manager will take over, and whether any would collide
hm-collisions:
    # Run before the first switch on a host. Classifies by where each path
    # resolves rather than by whether its leaf is a symlink, which is what makes
    # ~/.config/broot look like a conflict when it is not.
    @{{scripts}}/hm-collisions.sh {{host}} {{user}}

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
    @{{scripts}}/diff-config.sh {{ref}} {{host}}

# drvPath of the home activation package
fingerprint-home:
    @cd {{flake}} && nix eval --raw \
        '.#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.activationPackage.drvPath'
    @echo

# Every generated dotfile's attribute name -- run this before `just dotfile`
dotfiles:
    @{{scripts}}/dotfiles.sh {{host}} {{user}}

# A dotfile as home-manager actually generates it: `just dotfile ./.zshrc`
dotfile name:
    @{{scripts}}/dotfiles.sh {{host}} {{user}} '{{name}}'

# Can these packages build on a system, and does Homebrew already install them
available *pkgs:
    # Platform independent, like `just modules`, and defaults to aarch64-darwin
    # because that is the system the answer is usually wanted for. `--all`
    # sweeps every home.packages entry; `--duplicates` reports only the ones a
    # homebrew cask ALSO installs, and says what to do about each. Answers by
    # reading meta.platforms a question that used to be settled by eye, wrongly.
    @{{scripts}}/pkg-availability.py {{pkgs}}

# A host's sops recipient key: bare for this machine, a hostname to scan it
# remotely, --pubkey-file <path>, or --updatekeys to re-encrypt secrets.yaml
age-key *args:
    # Only ever reads a public key and prints -- does not edit .sops.yaml.
    # See flake/scripts/host-age-key.sh for why, and for the enrollment steps
    # it prints after the key.
    @{{scripts}}/host-age-key.sh {{args}}

# Has this already been seen? GitHub issues + wiki/ + lessons-learned.md
threads *term:
    @{{scripts}}/threads.sh {{term}}

# Update inputs, then re-check
update:
    cd {{flake}} && nix flake update
    @just check
