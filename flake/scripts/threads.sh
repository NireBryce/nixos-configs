#! /usr/bin/env bash
# Has this already been seen? One command instead of three greps and a
# `gh` invocation someone has to remember to run.
#
#   threads.sh <term> [<term> ...]
#
# Checks, in order: open GitHub issues (this repo only -- see the `gh
# issue list --repo` below), then `wiki/` (which includes
# `wiki/lessons-learned.md` -- it moved in from `claude cave/` 2026-09-02,
# so it no longer needs its own separate search path) and the repo-root
# `bugs pending submission/` for the same term.
#
# Exists because a ble.sh/carapace completion bug got independently
# rediscovered from scratch on 2026-08-24, at real cost, two days after it
# was first diagnosed and written up in wiki/categories/shell-config/blesh.md
# -- findable in one grep, never run. See `wiki/lessons-learned.md`
# #39 and issue #72. Run this before reproducing or diagnosing anything a
# user reports as a symptom, not just before filing something new -- see
# the `investigate-bug` skill.
set -euo pipefail

if (($# == 0)); then
    echo "usage: threads.sh <term> [<term> ...]" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# wiki/ and bugs pending submission/ both live at the true repo root, one
# level above flake/ -- this script sits in flake/scripts/, so that's two
# dirname calls up from here, not one.
repo_root=$(dirname -- "$(dirname -- "$script_dir")")
cd "$repo_root"

term=$*

echo "=== GitHub issues (NireBryce/nixos-configs) ==="
if command -v gh > /dev/null; then
    gh issue list --repo NireBryce/nixos-configs --search "$term" --state all \
        || echo "(gh issue list failed -- not authenticated? check by hand)"
else
    echo "(gh not installed -- skipping)"
fi

echo
echo "=== wiki/, bugs pending submission/ ==="
# Built from paths that actually exist rather than hardcoded: grep (ugrep on
# some systems) exits non-zero on a missing path even when other paths in
# the same invocation matched, which under `set -e` silently ate every real
# hit the one time this repo's own path assumption was wrong.
search_paths=(wiki)
[[ -d "bugs pending submission" ]] && search_paths+=("bugs pending submission")
if ! grep -rlin --include='*.md' -e "$term" "${search_paths[@]}" 2> /dev/null; then
    echo "(no matches)"
fi
