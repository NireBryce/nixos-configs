#!/usr/bin/env bash
# `just dev-list` / `just dev-new`: deploy one of the dev-shells/<name>/
# flake templates into a project folder from the repo root.
#
#   dev-shell.sh <dev-shells-dir> list
#   dev-shell.sh <dev-shells-dir> new <shell> <path> [--force]
#
# `new` delegates to the template's own `create` recipe, so per-language
# scaffolding (cargo init, uv init) and the `git add` of the copied files
# (flakes ignore untracked files; it has to sit between the copy and the
# template's own `nix develop`) stay in one place: dev-shells/<name>/
# justfile. Around it, this adds:
#   - resolves <path> to an absolute path and refuses one inside the
#     templates folder;
#   - refuses to overwrite an existing flake.nix unless --force;
#   - writes `.envrc` with `use flake` for direnv when none exists.
set -euo pipefail

usage="usage: dev-shell.sh <dev-shells-dir> list | new <shell> <path> [--force]"
dir=${1:?$usage}
cmd=${2:?$usage}

shells() {
    local d
    for d in "$dir"/*/; do
        if [ -f "$d/flake.nix" ]; then basename "$d"; fi
    done
}

case "$cmd" in
    list)
        shells
        ;;
    new)
        shell=${3:?$usage}
        target=${4:?$usage}
        force=${5:-}
        if [ $# -gt 5 ]; then
            echo "dev-new: too many arguments; $usage" >&2
            exit 2
        fi
        if [ -n "$force" ] && [ "$force" != "--force" ]; then
            echo "dev-new: unknown flag '$force' (only --force)" >&2
            exit 2
        fi

        # The template's `create` runs with its own folder as cwd, so a
        # relative target would land inside dev-shells/<shell>/. Resolve it
        # here, against the cwd `just dev-new` was run from ([no-cd]).
        target=$(realpath -m -- "$target")
        dir=$(realpath -- "$dir")
        case "$target/" in
            "$dir"/*)
                echo "dev-new: $target is inside $dir; pick a path outside the templates" >&2
                exit 1
                ;;
        esac

        if [ ! -f "$dir/$shell/flake.nix" ]; then
            echo "dev-new: no dev shell '$shell'. Available:" >&2
            shells | sed 's/^/  /' >&2
            exit 1
        fi
        if [ -e "$target/flake.nix" ] && [ "$force" != "--force" ]; then
            echo "dev-new: $target/flake.nix already exists; pass --force to overwrite" >&2
            exit 1
        fi

        just --justfile "$dir/$shell/justfile" create "$target"

        if [ ! -e "$target/.envrc" ]; then
            echo 'use flake' > "$target/.envrc"
            echo "dev-new: wrote $target/.envrc ('direnv allow' there to use it)"
        fi
        ;;
    *)
        echo "$usage" >&2
        exit 2
        ;;
esac
