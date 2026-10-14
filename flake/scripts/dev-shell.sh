#!/usr/bin/env bash
# `just dev-list` / `just dev-new`: deploy one of the dev-shells/<name>/
# flake templates into a project folder from the repo root.
#
#   dev-shell.sh <dev-shells-dir> list
#   dev-shell.sh <dev-shells-dir> new <shell> <path> [--force]
#
# `new` delegates to the template's own `create` recipe, so per-language
# scaffolding (cargo init, uv init) stays in one place: dev-shells/<name>/
# justfile. Around it, this adds:
#   - refuses to overwrite an existing flake.nix unless --force;
#   - when the target is in a git work tree, copies the template's files in
#     and `git add`s them BEFORE `create` runs. Flakes ignore untracked
#     files, and the python/rust `create` recipes run `nix develop` straight
#     after their own `cp` -- inside a repo that eval can't see an un-added
#     flake.nix (AGENTS.md, "git add before nix eval"). `create`'s `cp` then
#     rewrites the same content;
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
        if [ -n "$force" ] && [ "$force" != "--force" ]; then
            echo "dev-new: unknown flag '$force' (only --force)" >&2
            exit 2
        fi

        if [ ! -f "$dir/$shell/flake.nix" ]; then
            echo "dev-new: no dev shell '$shell'. Available:" >&2
            shells | sed 's/^/  /' >&2
            exit 1
        fi
        if [ -e "$target/flake.nix" ] && [ "$force" != "--force" ]; then
            echo "dev-new: $target/flake.nix already exists; pass --force to overwrite" >&2
            exit 1
        fi

        mkdir -p "$target"
        if git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            files=()
            for f in "$dir/$shell"/*; do
                name=$(basename "$f")
                if [ "$name" != justfile ] && [ -f "$f" ]; then
                    cp "$f" "$target/$name"
                    files+=("$name")
                fi
            done
            git -C "$target" add -- "${files[@]}"
            echo "dev-new: git-added ${files[*]} in $target (flakes ignore untracked files)"
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
