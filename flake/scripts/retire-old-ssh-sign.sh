#! /usr/bin/env bash
# Retire the hand-made git signing wrapper at ~/.config/git/ssh-sign.
#
#   retire-old-ssh-sign.sh [--apply] [--remove-script] [<repo>...]
#
# Before `elly-git.nix` set `gpg.ssh.program` to a store-path script, a
# hand-made ~/.config/git/ssh-sign did the same job, wired in by a
# `gpg.ssh.program` entry in a repo's own .git/config. Repo-local config
# overrides the global one, so that entry keeps the old script in use until it
# is removed. Home Manager does not manage .git/config or that script, and
# this is a one-time cleanup, so it is a script, not an activation step.
#
# Default is a dry run: it prints what it would change and changes nothing.
#
#   --apply          unset the repo-local `gpg.ssh.program` in each repo, but
#                    only when it is exactly the old script's path. Any other
#                    value is reported and left alone.
#   --remove-script  with --apply, also delete ~/.config/git/ssh-sign, unless
#                    one of the given repos still points at it. Repos you did
#                    not name are not checked.
#
# <repo> defaults to the repo this script lives in. Worktrees share their
# repo's .git/config, so naming any one worktree covers all of them.
set -euo pipefail

old_script="$HOME/.config/git/ssh-sign"
apply=false
remove_script=false
repos=()

for argument in "$@"; do
    case "$argument" in
        --apply) apply=true ;;
        --remove-script) remove_script=true ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        -*) echo "retire-old-ssh-sign: unknown option: $argument" >&2; exit 2 ;;
        *) repos+=("$argument") ;;
    esac
done

if $remove_script && ! $apply; then
    echo "retire-old-ssh-sign: --remove-script needs --apply" >&2
    exit 2
fi

if [[ ${#repos[@]} -eq 0 ]]; then
    repos=("$(cd "$(dirname "$0")" && git rev-parse --show-toplevel)")
fi

still_referenced=false

for repo in "${repos[@]}"; do
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "$repo: not a git repository, skipped" >&2
        continue
    fi
    value="$(git -C "$repo" config --local --get gpg.ssh.program || true)"
    if [[ -z "$value" ]]; then
        echo "$repo: no repo-local gpg.ssh.program"
    elif [[ "$value" == "$old_script" ]]; then
        if $apply; then
            git -C "$repo" config --local --unset gpg.ssh.program
            echo "$repo: removed repo-local gpg.ssh.program ($old_script)"
        else
            echo "$repo: would remove repo-local gpg.ssh.program ($old_script)"
        fi
    else
        echo "$repo: left alone, repo-local gpg.ssh.program is $value"
    fi
    if [[ "$value" == "$old_script" ]] && ! $apply; then
        still_referenced=true
    fi
done

if [[ ! -e "$old_script" ]]; then
    echo "$old_script: not present"
elif $remove_script; then
    if $still_referenced; then
        echo "$old_script: kept, a given repo still points at it"
    else
        rm -- "$old_script"
        echo "$old_script: removed"
    fi
else
    echo "$old_script: present (pass --apply --remove-script to delete it)"
fi
