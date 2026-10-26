#! /usr/bin/env bash
# Compare a host's evaluated config against an earlier git ref, attribute by
# attribute. An identical toplevel drvPath proves the output did not move; when
# it differs this says *what* differs, which a hash cannot.
#
#   diff-config.sh <git-ref> [host]
#
# Evaluation only -- nothing is built, so this works from darwin.
set -euo pipefail

ref=${1:-}
host=${2:-nire-durandal}
if [[ -z $ref ]]; then
    echo "usage: diff-config.sh <git-ref> [host]" >&2
    echo "  e.g. diff-config.sh HEAD~1 nire-tenacity" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "$script_dir")
repo_root=$(git -C "$flake_dir" rev-parse --show-toplevel)
flake_rel=${flake_dir#"$repo_root"/}
fingerprint=$script_dir/host-fingerprint.nix

git -C "$repo_root" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || {
    echo "diff-config.sh: '$ref' is not a commit" >&2; exit 2; }

# pwd -P: on macOS mktemp returns a path under /var, which is a symlink to
# /private/var, and nix refuses `path:` arguments that traverse a symlink.
worktree=$(cd -- "$(mktemp -d)" && pwd -P)
cleanup() { git -C "$repo_root" worktree remove --force "$worktree" >/dev/null 2>&1 || true; }
trap cleanup EXIT
git -C "$repo_root" worktree add -q --detach "$worktree" "$ref"

# The working tree is evaluated as-is, including uncommitted changes, but nix
# only sees git-tracked files -- so stage anything new before trusting this.
if [[ -n $(git -C "$repo_root" ls-files --others --exclude-standard -- "$flake_dir") ]]; then
    echo "warning: untracked files under $flake_rel are invisible to nix; git add them first" >&2
fi

echo "comparing $host:  $ref  ->  working tree"

before=$(mktemp); after=$(mktemp)
trap 'cleanup; rm -f "$before" "$after"' EXIT
FLAKE_PATH=$worktree/$flake_rel HOST=$host nix eval --impure --json --file "$fingerprint" >"$before"
FLAKE_PATH=$flake_dir            HOST=$host nix eval --impure --json --file "$fingerprint" >"$after"

python3 "$script_dir/diff_fingerprint.py" "$before" "$after"
